module importers

import os
import net.http
import time
import encoding.csv
import utils
import person

// Using the v3 minified URL as requested
const dir_import = os.getenv('TOMBSTONE_IMPORT')
const t4p_csv_url = 'https://data.techforpalestine.org/api/v3/killed-in-gaza.csv'
const cache_file = os.join_path(dir_import, 'last_download-killed-in-gaza.txt')

pub fn fetch_and_import() ![]person.Person {
	local_csv := os.join_path(dir_import, 'killed-in-gaza.min.csv')
	mut data := ''
	if os.exists(local_csv) {
		data = os.read_file(local_csv)!
		println('DEBUG: Read ${data.len} bytes from disk.')
	} else {
		println('Fetching CSV data...')
		mut req := http.new_request(.get, t4p_csv_url, '')
		if os.exists(cache_file) {
			last_mod := os.read_file(cache_file) or { '' }
			if last_mod != '' {
				req.add_header(.if_modified_since, last_mod)
				println('DEBUG: Sent If-Modified-Since: ${last_mod}')
			}
		}

		println('Checking for updates...')
		resp := req.do()!
		println('DEBUG: Server responded with status: ${resp.status_code}')
		println('DEBUG: Response Headers:\n${resp.header}')

		if resp.status_code == 304 {
			println('Data is up to date. Skipping download.')
			return []person.Person{}
		}

		if resp.status_code != 200 {
			return error('Failed to fetch data: HTTP ${resp.status_code}')
		}

		os.write_file(local_csv, resp.body) or {
			return error('CRITICAL: Failed to write CSV file: ${err}')
		}

		mut timestamp := resp.header.get(.last_modified) or { '' }
		if timestamp == '' {
			timestamp = resp.header.get(.date) or { '' }
		}

		if timestamp != '' {
			os.write_file(cache_file, timestamp) or {
				println('DEBUG: Warning - could not save cache_file: ${err}')
			}
		}

		data = resp.body
	}

	// Initialize the CSV reader on the response body
	mut reader := csv.new_reader(data)

	// Skip the header row: id,en_name,ar_name,age,dob,sex
	_ := reader.read() or { return error('Empty CSV file') }

	mut persons := []person.Person{}
	now := time.now()

	for {
		row := reader.read() or { break } // Stops at end of file

		// Mapping indexes: 0:id, 1:en_name, 2:ar_name, 3:age, 4:dob, 5:sex
		state_id := row[0]
		en_name := row[1]
		ar_name := row[2]
		sex_str := row[5]

		birth_date_obj, death_date_obj := parse_life_span(row[4], row[3])

		gender := match sex_str.trim_space() {
			'm' { person.Gender.male }
			'f' { person.Gender.female }
			else { person.Gender.unknown }
		}

		mut p := person.Person{
			external_ids: {
				't4p': state_id
			}
			locale:       'ar'
			gender:       gender
			name:         person.Name{
				native:       ar_name
				first:        en_name.all_before(' ')
				last:         en_name.all_after_last(' ')
				translations: {
					'en': en_name
				}
			}
			birth:        person.Event{
				date: birth_date_obj
			}
			death:        person.Event{
				date: death_date_obj
			}
			sources:      [
				person.Source{
					label: 'TechForPalestine Dataset (CSV)'
					url:   'https://techforpalestine.org'
				},
			]
			tags:         ['gaza', 'war']
			created:      now
			modified:     now
		}
		p.id = utils.create_id_from_seed(p.generate_fingerprint())
		persons << p
	}

	println('Successfully imported ${persons.len} persons from CSV.')
	return persons
}

fn get_unique_id(t4p_id string) string {
	// We know the source is T4P, so we prefix it to avoid collisions
	// with other future sources (like Wikipedia)
	return utils.create_id_from_seed('t4p-${t4p_id}')
}

// parse_life_span calculates the birth and death dates based on the available T4P columns.
// Since the conflict is ongoing across multiple calendar years, if we have an exact DOB 
// and an Age at death, we can determine the precise year they passed away.
fn parse_life_span(dob_str string, age_str string) (person.Date, person.Date) {
	mut birth := person.Date{year: 0, month: 0, day: 0}
	mut death := person.Date{year: 0, month: 0, day: 0}

	age := if age_str != '' { age_str.int() } else { -1 }

	// Scenario 1: Exact DOB is provided (YYYY-MM-DD)
	if dob_str != '' && dob_str.contains('-') {
		parts := dob_str.split('-')
		if parts.len == 3 {
			birth = person.Date{
				year:  u16(parts[0].u32())
				month: u8(parts[1].u32())
				day:   u8(parts[2].u32())
			}
			
			// If we have an exact DOB and an Age, Death Year = Birth Year + Age
			// Month and Day MUST be 0 because they are unknown!
			if age >= 0 {
				death = person.Date{
					year:  birth.year + u16(age)
					month: 0 // Correct: Unknown exact month
					day:   0 // Correct: Unknown exact day
				}
			}
			return birth, death
		}
	}

	// Scenario 2: DOB is missing, but we have an Age
	if age >= 0 && dob_str == '' {
		baseline_year := u16(2024)
		birth = person.Date{
			year:  baseline_year - u16(age)
			month: 0
			day:   0
		}
		death = person.Date{
			year:  baseline_year
			month: 0
			day:   0
		}
		return birth, death
	}

	return birth, death
}

