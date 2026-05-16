module main

import os
import json
import lib.person

const font_url = 'https://fonts.googleapis.com/css2?family=Amiri:ital,wght\@0,400;0,700;1,400;1,700&display=swap'

fn main() {
	dir_db := os.getenv('TOMBSTONE_DB')
	dir_html := os.getenv('TOMBSTONE_HTML')
	dir_import := os.getenv('TOMBSTONE_IMPORT')

	if dir_db.len == 0 || dir_html.len == 0 || dir_import.len == 0 {
		eprintln('Error: TOMBSTONE_xx environment variables are not set.')
		eprintln('Please run: source envvars')
		exit(1)
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

	build_home_index_page(dir_html, dir_db) or {
		eprintln('Failed to generate index file: ${err}')
		exit(1)
	}
}

// 1. Move processing out of the closure to guarantee 100% stable template injections
fn build_person_page(mut p person.Person, dir_html string) {
	slug_url := person.slugify(p)

	// Explicitly assign all local variable tokens for the template scope
	locale := p.locale
	native_name := p.name.native
	direction := if p.locale == 'ar' || p.locale == 'he' { 'rtl' } else { 'ltr' }

	// Build the class injection string dynamically based on locale flags
	name_classes := if p.locale == 'ar' { 'native-name arabic' } else { 'native-name' }

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
	// html_output := $tmpl('@VMODROOT/templates/person.html')
	html_output := $tmpl('../../templates/person.html')

	target_path := os.join_path(dir_html, 'person', '${slug_url}.html')
	os.write_file(target_path, html_output) or { return }
}

fn build_home_index_page(dir_html string, dir_db string) ! {
	// 1. Target the location of your compact summary dataset
	summary_path := os.join_path(dir_db, 'summary.json')
	if !os.exists(summary_path) {
		return error('Missing critical database map: ${summary_path}')
	}

	// 2. Read and decode the global summary data stream array
	json_data := os.read_file(summary_path)!
	summaries := json.decode([]person.Summary, json_data)!
	// 3. Prepare the dynamic injection parameters for the template scope
	total_records := summaries.len

	mut index_items_html := ''
	for s in summaries {
		slug := person.slugify(&s)
		display_name := s.translations['en'] or { s.name_native }

		// Build clean, semantic layout list items for the main index profile navigation
		index_items_html += '
		<li class="index-item">
			<a href="person/${slug}.html" class="index-link">
				<span class="ar-name arabic" dir="rtl">${s.name_native}</span>
				<span class="en-sub">${display_name}</span>
			</a>
		</li>'
	}

	// 4. Compile your new home template cleanly from the fixed root configuration folder
	html_output := $tmpl('../../templates/index.html')

	// 5. Save the compiled page directly into the root distribution html directory folder
	target_path := os.join_path(dir_html, 'index.html')
	os.write_file(target_path, html_output)!
	println('Successfully generated global search page index showing ${total_records} profiles.')
}
