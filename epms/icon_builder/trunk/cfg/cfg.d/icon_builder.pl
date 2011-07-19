$c->{plugins}{"Screen::IconBuilder"}{params}{disable} = 0;
$c->{plugins}{"Screen::IconBuilder"}{params}{secret} = join '', map {
	sprintf("%02x", int(rand(255)))
} 0 .. 31;
