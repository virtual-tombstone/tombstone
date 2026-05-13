module importers

import os
import net.http
import json
import time
import encoding.csv
import utils
import person

// Using the v3 minified URL as requested
const t4p_csv_url = 'https://data.techforpalestine.org/api/v3/killed-in-gaza.csv'
const cache_file = 'last_download-killed-in-gaza.txt'

pub fn fetch_and_import() ![]person.Person {
	local_csv := 'killed-in-gaza.min.csv'
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
		state_id:= row[0]
		en_name := row[1]
		ar_name := row[2]
		age_int := row[3].int()
		dob_str := row[4]
		sex_str := row[5]

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
				date: parse_birth_info(dob_str, age_int)
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
		fingerprint := p.generate_fingerprint()
		p.id = utils.create_id_from_seed(fingerprint)
		persons << p
	}

	println('Successfully imported ${persons.len} persons from CSV.')
	return persons
}

pub fn import_t4p(data string) ![]person.Person {
	// Decode as a raw 2D array: [][]string (or use any if types vary)
	// Since numbers are quoted as numbers in JSON, we'll use [][]any
	raw_data := json.decode([][]any, data)!

	mut persons := []person.Person{}
	now := time.now()

	// Skip index 0 because it is the header ["id", "en_name", ...]
	for i in 1 .. raw_data.len {
		row := raw_data[i]

		// Map indexes based on the header:
		// 0:id, 1:en_name, 2:ar_name, 3:age, 4:dob, 5:sex
		// id_from_source := row[0].str()
		en_name := row[1].str()
		println('en_name: ${en_name}')
		ar_name := row[2].str()

		age_str := row[3].str()
		println('age string: ${age_str}')
		// age := age_str.int()
		age := 5

		dob := row[4].str()
		sex := row[5].str()

		gender := match sex.trim_space() {
			'm' { person.Gender.male }
			'f' { person.Gender.female }
			else { person.Gender.unknown }
		}

		mut p := person.Person{
			id:       get_unique_id(row[0])
			gender:   gender
			name:     person.Name{
				native: ar_name
				first:  en_name.all_before(' ')
				last:   en_name.all_after(' ')
				translations: {
					'en': en_name
				}
			}
			birth:    person.Event{
				date: parse_birth_info(dob, age)
			}
			sources:  [
				person.Source{
					label: 'TechForPalestine Dataset (v3)'
					url:   'https://techforpalestine.org'
				},
			]
			created:  now
			modified: now
		}

		persons << p
	}
	return persons
}

fn get_unique_id(t4p_id string) string {
	// We know the source is T4P, so we prefix it to avoid collisions
	// with other future sources (like Wikipedia)
	return utils.create_id_from_seed('t4p-${t4p_id}')
}

pub fn parse_birth_info(dob_str string, age int) person.Date {
	// 1. Try to parse the DOB string (Expected format: YYYY-MM-DD)
	if dob_str != '' {
		parts := dob_str.split('-')
		if parts.len == 3 {
			return person.Date{
				year:  u16(parts[0].u32())
				month: u8(parts[1].u32())
				day:   u8(parts[2].u32())
			}
		}
		// If it's just a year string "YYYY"
		if parts.len == 1 && dob_str.len == 4 {
			return person.Date{
				year:  u16(dob_str.u32())
				month: 0
				day:   0
			}
		}
	}

	// 2. Fallback to Age-based estimate
	if age >= 0 {
		ref_year := 2024
		return person.Date{
			year:  u16(ref_year - age)
			month: 0
			day:   0
		}
	}

	// 3. Absolute Fallback (Unknown)
	return person.Date{
		year:  0
		month: 0
		day:   0
	}
}

