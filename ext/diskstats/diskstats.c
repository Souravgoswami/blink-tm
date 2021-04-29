#include <stdio.h>
#include <string.h>

#include <sys/ioctl.h>
#include <fcntl.h>
#include <linux/fs.h>

#include "ruby.h"
#include "sectors.h"

VALUE getDiskstats (volatile VALUE obj, volatile VALUE path) {
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

void Init_diskstats() {
	VALUE blink_tm = rb_define_module("BlinkTM") ;
	rb_define_module_function(blink_tm, "diskstats", getDiskstats, 1) ;
	rb_define_module_function(blink_tm, "get_sector_size", getSectorSize, 1) ;
}
