/*
	Source:
	https://commandlinefanatic.com/cgi-bin/showarticle.cgi?article=art008

	Note that this obeys the standard and matches with Ruby's Zlib.crc32(...)
*/

#define CRC32_DIVISOR 0xEDB88320
#include "ruby.h"

static VALUE getCRC(volatile VALUE obj, volatile VALUE str) {
	char *input = StringValuePtr(str) ;
	unsigned char len = strlen(input) ;
	unsigned long crc = 0xFFFFFFFF ;

	for (unsigned char i = 0 ; i < len ; ++i) {
		crc ^= input[i] ;

		for (unsigned char k = 8 ; k ; --k) {
			crc = crc & 1 ? (crc >> 1) ^ CRC32_DIVISOR : crc >> 1 ;
		}
	}

	char buffer[11] ;
	sprintf(buffer, "%lu", crc ^ 0xFFFFFFFF) ;

	return rb_str_new_cstr(buffer) ;
}

void Init_crc32() {
	VALUE blinktm = rb_define_module("BlinkTM") ;
	rb_define_module_function(blinktm, "crc32", getCRC, 1) ;
}
