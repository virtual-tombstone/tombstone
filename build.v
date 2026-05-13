module main

import os
import json
import lib.person

fn main() {
	dir_db := os.getenv('TOMBSTONE_DB')
	dir_html := os.getenv('TOMBSTONE_HTML')
	dir_import := os.getenv('TOMBSTONE_IMPORT')

	if dir_db.len == 0 || dir_html.len == 0 || dir_import.len == 0 {
		eprintln('Error: TOMBSTONE_xx environment variables are not set.')
		eprintln('Please run: source envvars')
		exit(1) // Stop safely before paths explode
	}

	// Setup output directory structure
	os.mkdir_all(os.join_path_single(dir_html, 'person')) or { panic(err) }
	os.cp_all('static', dir_html, true)!

	// 1. Walk through the sharded storage folder structure
	os.walk(dir_db, fn [dir_html] (path string) {
		// Skip directories or non-JSON files
		if !path.ends_with('.json') || os.is_dir(path) {
			return
		}

		// 2. Read and parse the absolute truth: The full Person record
		json_data := os.read_file(path) or { return }
		mut p := json.decode(person.Person, json_data) or { return }

		// 3. Generate the 100% correct deterministic slug using the full struct
		slug_url := p.slugify()

		// 4. Map variables for your external templates/person.html file
		locale := p.locale
		native_name := p.name.native
		direction := if p.locale == 'ar' || p.locale == 'he' { 'rtl' } else { 'ltr' }
		person_id := p.id

		// Call global formatting function passing the Option types
		b_str := person.format_event_date(p.birth)
		d_str := person.format_event_date(p.death)

		// Map to template layout string tokens with fallback formatting
		birth_date := if b_str != '' { b_str } else { '—' }
		death_date := if d_str != '' { d_str } else { '—' }

		// Extract values safely by borrowing the map reference in an if-let block
		mut display_name := 'Unknown'
		mut translation_json := '{}'
		if t := p.name.translations {
			display_name = t['en'] or { 'Unknown' }
			translation_json = json.encode(t)
		}

		if display_name == '' {
			display_name = p.name.native
		}

		keywords_txt := p.tags.join(', ')
		meta_desc := 'Digital memorial for ${native_name} (${display_name}). Born: ${birth_date}. Martyred: ${death_date}.'

		mut tags_html := ''
		for tag in p.tags {
			tags_html += '<span class="tag">#${tag}</span> '
		}

		// 5. Compile the template (Fixed: added os. prefix)
		html_output := $tmpl('templates/person.html')

		// 6. Save the flat file directly into your flat HTML folder
		target_path := os.join_path(dir_html, 'person', '${slug_url}.html')
		os.write_file(target_path, html_output) or { return }
	})
}

