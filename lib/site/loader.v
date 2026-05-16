module site

import os
import json
import person

pub struct SiteData {
pub mut:
	cemeteries map[string]person.Cemetery
	summaries  []person.Summary
}

// load_site_data reads the sharded data and populates a SiteData struct
pub fn load_site_data(data_path string) !SiteData {
	mut data := SiteData{
		cemeteries: map[string]person.Cemetery{}
		summaries:  []person.Summary{}
	}

	// 1. Load Cemetery Shards (e.g., data/cemeteries/ps.json)
	cemetery_dir := os.join_path(data_path, 'cemeteries')
	if os.exists(cemetery_dir) {
		files := os.ls(cemetery_dir)!
		for file in files {
			if file.ends_with('.json') {
				path := os.join_path(cemetery_dir, file)
				raw := os.read_file(path)!
				shard := json.decode([]person.Cemetery, raw)!
				for c in shard {
					data.cemeteries[c.id] = c
				}
			}
		}
	}

	// 2. Load Master Summary Index (data/summary.json)
	summary_path := os.join_path(data_path, 'summary.json')
	if os.exists(summary_path) {
		raw := os.read_file(summary_path)!
		data.summaries = json.decode([]person.Summary, raw)!
	}

	return data
}
