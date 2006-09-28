
######################################################################
#
# User Roles
#
#  Here you can configure which different types of user are 
#  parts of the system they are allowed to use.
#
######################################################################

	
$c->{user_roles}->{user} = [qw/
	general
	edit-own-record
	subscription
	set-password
	deposit
	change-email
/],

$c->{user_roles}->{editor} = [qw/
	general
	edit-own-record
	subscription
	set-password
	deposit
	change-email
	editor
	view-status
	staff-view
/],

$c->{user_roles}->{admin} = [qw/
	general
	edit-own-record
	subscription
	set-password
	deposit
	change-email
	editor
	view-status
	staff-view
	edit-subject
	edit-user
/],


#$c->{user_roles}->{minuser} = [qw/
#	subscription
#	set-password
#	change-email
#	change-user
#	no_edit_own_record
#	lock-username-to-email
#/];
