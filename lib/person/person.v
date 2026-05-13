module person

import time
import utils

pub struct Person {
pub:
	external_ids map[string]string
	gender       Gender
	name         Name
	locale       string
	birth        ?Event
	death        ?Event
	plot         ?Plot
	inscriptions []Inscription
	family       []Family
	links        map[string]string
	sources      []Source
	tags         []string
	created      time.Time
	modified     time.Time
	extra        ?map[string]string
pub mut:
	id           string
}

// To build index pages
pub struct Summary {
pub:
	id           string
	locale       string
	name_native  string
	translations map[string]string
	birth        ?string
	death        ?string
	tags         []string
}

pub enum Gender {
	unknown
	male
	female
}

pub struct Source {
pub:
	label string
	url   string
}

pub struct Name {
pub:
	native       string // original native name
	first        string
	middle       ?string
	last         string
	suffix       ?string
	maiden       ?string
	translations ?map[string]string
}

pub struct Event {
pub:
	date    ?Date
	country ?string
	city    ?string
	town    ?string
	lat     ?f64
	lon     ?f64
}

pub fn format_event_date(e ?Event) string {
	if evt := e {
		if d := evt.date {
			return d.str()
		}
	}
	return ''
}

pub struct Date {
pub:
	year  u16 // Supports 0 to 65,535
	month u8  // 1-12 (0 = unknown)
	day   u8  // 1-31 (0 = unknown)
}

// Returns a formatted string: YYYY, YYYY-MM, or YYYY-MM-DD
pub fn (d Date) str() string {
	if d.month == 0 {
		return '${d.year}'
	}
	if d.day == 0 {
		// Use :02 for padding u8 integers
		return '${d.year}-${d.month:02}'
	}
	return '${d.year}-${d.month:02}-${d.day:02}'
}

pub struct Cemetery {
pub:
	id      string
	name    string
	city    string
	country string
}

pub struct Plot {
pub:
	cemetery_id string
	status      Disposition
	section     ?string
	row         ?string
	number      ?string
	lat         ?f64
	lon         ?f64
}

pub enum Disposition {
	buried
	cremated
	lost_at_sea
	missing_unrecovered
	donated_to_science
}

struct Inscription {
	lang string
	text string
}

struct Family {
	id           string // The 'id' of the related Person
	relationship string // e.g., "Father", "Spouse", "Daughter"
	name_preview string // A string to show if the related page doesn't exist yet
}


pub interface IsSlugable {
	get_id() string
	get_name_native() string
	get_translations() map[string]string
}

pub fn (p Person) get_id() string {
	return p.id
}

pub fn (p Person) get_name_native() string {
	return p.name.native
}

pub fn (p Person) get_translations() map[string]string {
	return p.name.translations or { map[string]string{} }
}

pub fn (s Summary) get_id() string {
	return s.id
}

pub fn (s Summary) get_name_native() string {
	return s.name_native
}

pub fn (s Summary) get_translations() map[string]string {
	return s.translations
}

// slugify turns "Jamal Abu Hasan" into "jamal-abu-hasan-id" (determanistic slug)
pub fn slugify(item IsSlugable) string {
	id := item.get_id()
	translations := item.get_translations()
	
	en_name := translations['en'] or { item.get_name_native() }
	mut res := en_name.to_lower().replace(' ', '-')
	
	// Keep only alphanumeric and dashes
	mut clean := []u8{}
	for b in res {
		if (b >= `a` && b <= `z`) || (b >= `0` && b <= `9`) || b == `-` {
			clean << b
		}
	}
	
	tmp := clean.bytestr().split('-').filter(it != '').join('-')
	return if tmp.len > 0 { '${tmp}-${id}' } else { id }
}

pub fn create_id() string {
	return utils.rand_string(10, 10, utils.charset_read_safe)
}

pub fn (p Person) generate_fingerprint() string {

	norm_name := p.name.native.to_lower().replace(' ', '')
	
	mut year := '0'
	mut month := '0'
	mut day := '0'

	if b := p.birth {
		if d := b.date {
			year = d.year.str()
			// Use :02 padding to keep the string length consistent
			month = d.month.str()
			day = d.day.str()
		}
	}
	return '${norm_name}-${year}-${month}-${day}'
}

