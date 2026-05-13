module main

//import os
import lib.store
import lib.importers

fn main() {

	// os.rmdir_all('data') or { eprintln(err); exit(1)}
	// os.mkdir_all('data') or { eprintln(err); exit(1)}
	// exit(0)
	// 1. Fetch live data
	all_persons := importers.fetch_and_import() or { panic(err) }
	println('DEBUG: Importer returned ${all_persons.len} persons.') // <--- Add this

	// 2. Initialize your DiskStore (sharded storage)
	mut ds := store.new_disk_store('data/', 'data/summary.json', 'data/cemeteries/')

	// 3. Save only the first 10 for testing
	println('Saving test batch...')
	for i in 0 .. 10 {
		mut p := all_persons[i]
		// p.id = p.slugify() // Use your deterministic slug logic
		ds.save(p) or { continue }
	}

	// 4. Finalize the index files
	ds.flush_all() or { panic(err) }
	println('Import complete. Data saved to ./data')
}

