module utils

// import utils
// fn main() {
//	rand.seed(seed.time_seed_array(2))
//    s := utils.rand_string(10, 20, utils.charset_standard)
// }
import strings
import rand
import rand.seed
import rand.wyrand

pub const charset_standard = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
pub const charset_read_safe = 'ABCDEFHJLMNQRTUVWXYZabcefghijkmnopqrtuvwxyz23479'
pub const charset_json_safe = get_json_safe_ascii()

pub fn rand_string(min int, max int, charset string) string {
	rand.seed(seed.time_seed_array(2))
	length := if min < max {
		rand.int_in_range(min, max) or { min }
	} else {
		min
	}

	mut buf := []u8{len: length}
	for i in 0 .. length {
		buf[i] = charset[rand.intn(charset.len) or { 0 }]
	}
	return buf.bytestr()
}

// Deterministic ID generator (The duplication-killer)
pub fn create_id_from_seed(seed_text string) string {
	// 1. Create a numeric seed from the string hash
	hash_val := u32(seed_text.hash())

	// 2. Initialize the generator and cast it to the PRNG interface
	// This "unlocks" the high-level methods like intn/u32n
	mut rng := rand.PRNG(&wyrand.WyRandRNG{})
	rng.seed([hash_val, hash_val])

	// 3. Build the 10-char string
	mut result := []u8{len: 10}
	for i in 0 .. 10 {
		// Use u32n or intn as a method of the PRNG interface
		idx := rng.u32n(u32(charset_read_safe.len)) or { 0 }
		result[i] = charset_read_safe[idx]
	}
	return result.bytestr()
}

fn get_json_safe_ascii() string {
	mut sb := strings.new_builder(95)
	for i in 33 .. 127 {
		if i == 34 || i == 92 {
			continue
		}
		sb.write_u8(u8(i))
	}
	return sb.str()
}
