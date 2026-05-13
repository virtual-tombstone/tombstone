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
		// Guard against non-json files
		if !path.ends_with('.json') || os.is_dir(path) {
			return
		}

		json_data := os.read_file(path) or { return }
		mut p := json.decode(person.Person, json_data) or { return }

		// Ensure we only process if the record parsed out an actual ID
		if p.id == '' {
			return
		}

		// Invoke your page generator passing the clean data context
		build_person_page(mut p, dir_html)
	})
}

// 1. Move processing out of the closure to guarantee 100% stable template injections
fn build_person_page(mut p person.Person, dir_html string) {
	slug_url := p.slugify()

	// Explicitly assign all local variable tokens for the template scope
	locale := p.locale
	native_name := p.name.native
	direction := if p.locale == 'ar' || p.locale == 'he' { 'rtl' } else { 'ltr' }
	person_id := p.id

	// Unwrapping birth/death variables safely
	b_str := person.format_event_date(p.birth)
	d_str := person.format_event_date(p.death)
	birth_date := if b_str != '' { b_str } else { '—' }
	death_date := if d_str != '' { d_str } else { '—' }

	mut display_name := p.name.native
	mut translation_json := '{}'
	if t := p.name.translations {
		display_name = t['en'] or { p.name.native }
		translation_json = json.encode(t)
	}

	keywords_txt := p.tags.join(', ')
	meta_desc := 'Digital memorial for ${native_name} (${display_name}). Born: ${birth_date}. Martyred: ${death_date}.'

	mut tags_html := ''
	for tag in p.tags {
		tags_html += '<span class="tag">#${tag}</span> '
	}

	// This now compiles safely because it sits inside a clean, first-class function scope!
	html_output := $tmpl('templates/person.html')

	target_path := os.join_path(dir_html, 'person', '${slug_url}.html')
	os.write_file(target_path, html_output) or { return }
}

