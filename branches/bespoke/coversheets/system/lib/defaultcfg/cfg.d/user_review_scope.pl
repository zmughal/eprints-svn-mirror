
# Fields used for limiting the scope of editors
$c->{editor_limit_fields} =
[
	"divisions",
	"subjects",
	"type",
];

#backwards compatibility
$c->{editpermfields} = $c->{editor_limit_fields};
