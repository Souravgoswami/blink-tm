VALUE getSectorSize (volatile VALUE obj, volatile VALUE path) {
	char *dev = StringValuePtr(path) ;

	unsigned int fd ;
	unsigned int sSize = 0 ;

	fd = open(dev, O_RDONLY | O_NONBLOCK) ;
	if(fd < 0) return Qnil ;

	short status = ioctl(fd, BLKSSZGET, &sSize) ;
	close(fd) ;
	if(status < 0) return Qnil ;

	return USHORT2NUM(sSize) ;
}
