module main

import os
import json
import lib.site

fn main() {
	println('Loading data...')
	data := site.load_site_data('data') or {
		eprintln('Error loading data: ${err}')
		return
	}

	// Setup output directory
	os.mkdir_all('dist/person') or { panic(err) }
	os.cp_all('static', 'dist', true)!

	// Limit to the first 10 for testing
	// Using .len check to avoid 'out of bounds' if dataset is smaller than 10
	limit := if data.summaries.len < 10 { data.summaries.len } else { 10 }
	test_batch := data.summaries[0..limit]

	println('Generating ${limit} test pages...')

	for s in test_batch {
		// 1. Unwrap the Option types for the HTML template
		birth_date := s.birth or { '' }
		death_date := s.death or { '' }
		translation_json := json.encode(s.translations)
		native_name := s.name_native
		direction := if s.locale == 'ar' || s.locale == 'he' { 'rtl' } else { 'ltr' }
		meta_desc := 'Digital memorial for ${s.name_native} . ' +
			'Born: ${birth_date}. Martyred: ${death_date}.'
		mut keywords := s.tags.join(', ')

		mut tags_html := ''
		for tag in s.tags {
			tags_html += '<span class="tag">#${tag}</span> '
		}

		html := '<!DOCTYPE html>
<html lang="${s.locale}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${s.name_native}</title>
    <meta name="description" content="${meta_desc}">
    <meta name="keywords" content="${keywords}">
    <link rel="stylesheet" href="../css/style.css">
    <script src="../js/lang-switcher.js" defer></script>
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Amiri:ital,wght@0,400;0,700;1,400;1,700&display=swap" rel="stylesheet">
</head>
<body>
    <nav class="lang-nav">
        <button onclick="location.hash=\'en\'">English</button>
        <button onclick="location.hash=\'ar\'">العربية</button>
    </nav>

    <main class="memorial-container">
        <article class="memorial-card">
            <header class="memorial-header">
                <!-- Original name: The anchor of the page -->
                <h1 class="native-name" dir="${direction}">${native_name}</h1>
                
                <!-- Subtitle: Updated by JS from the translations map -->
                <h2 id="name-translation" class="translation-subtitle" data-translations=\'${translation_json}\'></h2>
            </header>

            <section class="memorial-content">
                <div class="life-dates">
                    <p>
                        <span data-translations=\'{"en": "Born", "ar": "ولد"}\'>Born</span>: 
                        ${birth_date}
                    </p>
                    <p>
                        <span data-translations=\'{"en": "Martyred", "ar": "استشهد"}\'>Martyred</span>: 
                        ${death_date}
                    </p>
                </div>
                
                <div class="tags">
                    ${tags_html}
                </div>
            </section>

            <footer class="memorial-footer">
                <hr>
                <a href="/index.html" data-translations=\'{"en": "← Back to Index", "ar": "← العودة إلى الفهرس"}\'>← Back to Index</a>
                <p class="id-badge">ID: ${s.id}</p>
            </footer>
        </article>
    </main>
</body>
</html>'

		out_path := os.join_path('dist/person', '${s.id}.html')

		os.write_file(out_path, html) or {
			eprintln('Failed to write ${s.id}: ${err}')
			continue
		}
	}

	// Generate a simple Index page for the 10 people
	mut index_html := '<h1>Test Index</h1><ul>'
	for s in test_batch {
		index_html += '<li><a href="person/${s.id}.html">${s.name_native}</a></li>'
	}
	index_html += '</ul>'
	os.write_file('dist/index.html', index_html) or { panic(err) }

	println('Test build complete. Open ./dist/index.html to view.')
}

