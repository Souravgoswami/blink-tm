#include <stdio.h>
#include <fcntl.h>
#include <termios.h>
#include "ruby.h"

VALUE setBaudRate(volatile VALUE obj, volatile VALUE dev, volatile VALUE speed) {
	char *device = StringValuePtr(dev) ;
	unsigned int spd = NUM2UINT(speed) ;

	int serial_port = open(device, O_RDWR | O_NOCTTY) ;
	struct termios tty ;

	char status = tcgetattr(serial_port, &tty) ;

	/*
		Serial Monitor sets these flags:

		speed 57600 baud; line = 0;
		min = 0; time = 0;
		-brkint -icrnl -imaxbel
		-opost
		-isig -icanon -iexten -echo -echoe -echok -echoctl -echoke
	*/

	if(status != 0) {
		close(serial_port) ;
		return Qnil ;
	}

	tty.c_cflag &= ~CSIZE ;
	tty.c_cflag |= CS8 ;
	tty.c_cflag |= CREAD | CLOCAL ;
	tty.c_oflag &= ~OPOST ;

	tty.c_lflag &= ~ECHO ;
	tty.c_lflag &= ~ECHOCTL ;
	tty.c_lflag &= ~ECHOK ;
	tty.c_lflag &= ~ECHOE ;
	tty.c_lflag &= ~ECHOKE ;
	tty.c_lflag &= ~ISIG ;
	tty.c_lflag &= ~ICRNL ;
	tty.c_lflag &= ~IEXTEN ;
	tty.c_lflag &= ~ICANON ;

	tty.c_cc[VTIME] = 0 ;
	tty.c_cc[VMIN] = 0 ;

	cfsetispeed(&tty, spd) ;
	cfsetospeed(&tty, spd) ;
	status = tcsetattr(serial_port, TCSANOW, &tty) ;

	close(serial_port) ;

	if (status == 0) return Qtrue ;
	return Qfalse ;
}

VALUE getBaudRate(volatile VALUE obj, volatile VALUE dev) {
	char *device = StringValuePtr(dev) ;

	int serial_port = open(device, O_RDWR | O_NOCTTY | O_NONBLOCK) ;
	struct termios tty ;

	char status = tcgetattr(serial_port, &tty) ;
	close(serial_port) ;

	if(status == 0) {
		unsigned int in = cfgetispeed(&tty) ;
		unsigned int out = cfgetospeed(&tty) ;

		return rb_ary_new_from_args(2,
			UINT2NUM(in), UINT2NUM(out)
		) ;
	}

	return rb_ary_new() ;
}

void Init_baudrate() {
	VALUE blinktm = rb_define_module("BlinkTM") ;
	rb_define_const(blinktm, "B0", INT2FIX(B0)) ;
	rb_define_const(blinktm, "B50", INT2FIX(B50)) ;
	rb_define_const(blinktm, "B75", INT2FIX(B75)) ;
	rb_define_const(blinktm, "B110", INT2FIX(B110)) ;
	rb_define_const(blinktm, "B134", INT2FIX(B134)) ;
	rb_define_const(blinktm, "B150", INT2FIX(B150)) ;
	rb_define_const(blinktm, "B200", INT2FIX(B200)) ;
	rb_define_const(blinktm, "B300", INT2FIX(B300)) ;
	rb_define_const(blinktm, "B600", INT2FIX(B600)) ;
	rb_define_const(blinktm, "B1200", INT2FIX(B1200)) ;
	rb_define_const(blinktm, "B1800", INT2FIX(B1800)) ;
	rb_define_const(blinktm, "B2400", INT2FIX(B2400)) ;
	rb_define_const(blinktm, "B4800", INT2FIX(B4800)) ;
	rb_define_const(blinktm, "B9600", INT2FIX(B9600)) ;
	rb_define_const(blinktm, "B19200", INT2FIX(B19200)) ;
	rb_define_const(blinktm, "B38400", INT2FIX(B38400)) ;
	rb_define_const(blinktm, "B57600", INT2FIX(B57600)) ;
	rb_define_const(blinktm, "B115200", INT2FIX(B115200)) ;

	rb_define_module_function(blinktm, "set_baudrate", setBaudRate, 2) ;

	rb_define_module_function(blinktm, "get_baudrate", getBaudRate, 1) ;
	rb_define_module_function(blinktm, "baudrate", getBaudRate, 1) ;
}
