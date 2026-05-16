module main

import os
import lib.store
import lib.importers

fn main() {
	dir_db := os.getenv('TOMBSTONE_DB')
	dir_html := os.getenv('TOMBSTONE_HTML')
	dir_import := os.getenv('TOMBSTONE_IMPORT')

	if dir_db.len == 0 || dir_html.len == 0 || dir_import.len == 0 {
		eprintln('Error: Critical TOMBSTONE environment variables are missing.')
		eprintln('Please run: source envvars')
		exit(1)
	}

	// 1. Fetch live data
	all_persons := importers.fetch_and_import() or { panic(err) }
	println('DEBUG: Importer returned ${all_persons.len} persons.')

	// 2. Initialize your DiskStore (sharded storage)
	mut ds := store.new_disk_store(dir_db, os.join_path_single(dir_db, 'summary.json'),
		os.join_path_single(dir_db, 'cemeteries'))

	// Read the dev limit from environment, fallback to 10 if empty or 0
	env_limit := os.getenv('TOMBSTONE_DEV_LIMIT').int()
	limit := if env_limit > 0 { env_limit } else { all_persons.len }

	println('Saving test batch of ${limit} records...')
	for i in 0 .. limit {
		// Safe check in case the dataset has fewer rows than the limit
		if i >= all_persons.len {
			break
		}

		mut p := all_persons[i]
		ds.save(p) or { continue }
	}

	// Finalize the index files
	ds.flush_all() or { panic(err) }
	println('Import complete. Data saved to ${dir_db} ')

	// Trigger the search shard compiler pass right before finishing
	importers.generate_search_shards(dir_db, dir_html) or {
		eprintln('Failed to generate search indexes: ${err}')
		exit(1)
	}
}
