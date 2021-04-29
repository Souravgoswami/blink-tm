#include <stdio.h>
#include <string.h>
#include "ruby.h"

VALUE get_diskstats (VALUE obj, VALUE path) {
	FILE *file = fopen("/proc/diskstats", "r") ;
	if(!file) return rb_ary_new() ;

	char lines[120] ;
	unsigned long long read, write ;
	char *p = StringValuePtr(path) ;

	while(fgets(lines, 119, file)) {
		sscanf(lines, "%*s %*s %s %*s %*s %llu %*s %*s %*s %llu", lines, &read, &write) ;

		if(strcmp(lines, p) == 0) {
			return rb_ary_new_from_args(
				2,
				ULL2NUM(read),
				ULL2NUM(write)
			) ;
		}
	}

	return rb_ary_new() ;
}

int Init_diskstats() {
	VALUE blink_tm = rb_define_module("BlinkTM") ;
	rb_define_module_function(blink_tm, "diskstats", get_diskstats, 1) ;
}
