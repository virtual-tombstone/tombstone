module store

import os
import json
import person

pub struct DiskStore {
pub:
	base_path    string
	index_path   string
	cemetery_dir string // Path to a directory, e.g., "data/cemeteries/"
mut:
	summary_map map[string]person.Summary
	// map[country]map[id]Cemetery
	cemetery_shards map[string]map[string]person.Cemetery
}

// transforms "abcde" to "base_path/ab/cd/abcde.json"
fn (d DiskStore) get_path(id string) string {
	if id.len < 4 {
		return os.join_path(d.base_path, id + '.json')
	}
	dir := os.join_path(d.base_path, id[0..2], id[2..4])
	return os.join_path(dir, id + '.json')
}

pub fn new_disk_store(base_path string, index_path string, cemetery_dir string) DiskStore {
	os.mkdir_all(base_path) or {
		eprintln('new_disk_store: ${err.str()}')
		exit(1)
	}
	mut ds := DiskStore{
		base_path:       base_path
		index_path:      index_path
		cemetery_dir:    cemetery_dir
		summary_map:     map[string]person.Summary{}
		cemetery_shards: map[string]map[string]person.Cemetery{}
	}
	ds.load_index_to_memory()
	// TODO: load cemeteries here too if needed
	return ds
}

fn (mut d DiskStore) load_index_to_memory() {
	if !os.exists(d.index_path) {
		return
	}
	raw := os.read_file(d.index_path) or { return }
	list := json.decode([]person.Summary, raw) or { []person.Summary{} }
	for item in list {
		d.summary_map[item.id] = item
	}
}

pub fn (mut d DiskStore) save(p person.Person) ! {
	full_path := d.get_path(p.id)
	println('DEBUG STORE: Saving ${p.id} to ${full_path}') // <--- Add this

	dir := os.dir(full_path)
	if !os.exists(dir) {
		os.mkdir_all(dir) or { return error('Failed to create dir: ${dir}') }
	}

	os.write_file(full_path, json.encode(p)) or { return error('Failed to write file') }

	d.summary_map[p.id] = person.Summary{
		id:          p.id
		locale:      p.locale
		name_native: p.name.native
		// FIX: Explicitly ensure the translations dictionary is assigned
		translations: p.name.translations or {
			map[string]string{}
		}
		birth:        person.format_event_date(p.birth)
		death:        person.format_event_date(p.death)
		tags:         p.tags
	}

	if plot := p.plot {
		cid := plot.cemetery_id
		if cid != '' {
			// Determine country from the Person's record if possible
			// 1. Get the country from the death event if it exists
			// 2. Fall back to 'unknown' if either the event or the country string is missing
			country := if dth := p.death {
				dth.country or { 'unknown' }
			} else {
				'unknown'
			}.to_lower()

			if country !in d.cemetery_shards {
				d.cemetery_shards[country] = map[string]person.Cemetery{}
			}

			// Only create a placeholder if it wasn't pre-registered
			if cid !in d.cemetery_shards[country] {
				d.cemetery_shards[country][cid] = person.Cemetery{
					id:      cid
					name:    'Placeholder: ${cid}'
					country: country
				}
			}
		}
	}
}

pub fn (d DiskStore) flush_all() ! {
	// 1. Save Person Summary (The master list)
	mut s_list := []person.Summary{}
	for _, v in d.summary_map {
		s_list << v
	}
	os.write_file(d.index_path, json.encode(s_list))!

	// 2. Save Cemetery Shards
	if !os.exists(d.cemetery_dir) {
		os.mkdir_all(d.cemetery_dir)!
	}

	for country, shard in d.cemetery_shards {
		mut c_list := []person.Cemetery{}
		for _, v in shard {
			c_list << v
		}

		shard_path := os.join_path(d.cemetery_dir, '${country}.json')
		os.write_file(shard_path, json.encode(c_list))!
	}
}

pub fn (mut d DiskStore) register_cemetery(c person.Cemetery) {
	// 1. Identify the country (default to 'unknown' if empty)
	country := if c.country != '' { c.country.to_lower() } else { 'unknown' }

	// 2. Initialize the country shard if it doesn't exist
	if country !in d.cemetery_shards {
		d.cemetery_shards[country] = map[string]person.Cemetery{}
	}

	// 3. Save/Update the cemetery metadata in the shard
	// This will overwrite the "Unknown Cemetery" placeholder if it was already there
	d.cemetery_shards[country][c.id] = c
}

fn (d DiskStore) load_summary() []person.Summary {
	if !os.exists(d.index_path) {
		return []person.Summary{}
	}
	raw := os.read_file(d.index_path) or { return []person.Summary{} }
	return json.decode([]person.Summary, raw) or { []person.Summary{} }
}
