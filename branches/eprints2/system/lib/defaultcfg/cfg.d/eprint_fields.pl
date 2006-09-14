
$c->{fields}->{eprint} = [

#	{ name=>"authors", type=>"compound", multiple=>1, fields=>
#		{ name=>"authors_name", type=>"name" },
#		{ name=>"authors_email", type=>"email" },
#	}},


#	{ name => "creators", type => "name", multiple => 1, input_boxes => 4,
#		hasid => 1, input_id_cols=>20, 
#		family_first=>1, hide_honourific=>1, hide_lineage=>1 }, 

	{ name => "creators", type => "name", multiple => 1, input_boxes => 4,
		family_first=>1, hide_honourific=>1, hide_lineage=>1, allow_null=>1 }, 
	{ name => "creators_id", type => "text", multiple=>1, allow_null=>1, input_cols=>20 },
	{ name => "creators_list", type=>"compound",  multiple=>1,
		fields=>{id=>"creators_id", main=>"creators"} },

	{ name => "title", type => "longtext", multilang=>0, input_rows => 3 },

	{ name => "ispublished", type => "set", 
			options => [ "pub","inpress","submitted" , "unpub" ] },

	{ name => "subjects", type=>"subject", top=>"subjects", multiple => 1, 
		browse_link => "subjects",
		render_input=>"EPrints::Extras::subject_browser_input" },

	{ name => "full_text_status", type=>"set",
			options => [ "public", "restricted", "none" ] },

	{ name => "monograph_type", type=>"set",
			options => [ 
				"technical_report", 
				"project_report",
				"documentation",
				"manual",
				"working_paper",
				"discussion_paper",
				"other" ] },



	{ name => "pres_type", type=>"set",
			options => [ 
				"paper", 
				"lecture", 
				"speech", 
				"poster", 
				"other" ] },

	{ name => "keywords", type => "longtext", input_rows => 2 },

	{ name => "note", type => "longtext", input_rows => 3 },

	{ name => "suggestions", type => "longtext" },

	{ name => "abstract", input_rows => 10, type => "longtext" },

	{ name => "date_sub", type=>"date", min_resolution=>"year" },

	{ name => "date_issue", type=>"date", min_resolution=>"year" },

	{ name => "date_effective", type=>"date", min_resolution=>"year" },

	{ name => "series", type => "text" },

	{ name => "publication", type => "text" },

	{ name => "volume", type => "text", maxlength => 6 },

	{ name => "number", type => "text", maxlength => 6 },

	{ name => "publisher", type => "text" },

	{ name => "place_of_pub", type => "text" },

	{ name => "pagerange", type => "pagerange" },

	{ name => "pages", type => "int", maxlength => 6, sql_index => 0 },

	{ name => "event_title", type => "text" },

	{ name => "event_location", type => "text" },
	
	{ name => "event_dates", type => "text" },

	{ name => "event_type", type => "set", options=>[ "conference","workshop","other" ] },

	{ name => "id_number", type => "text" },

	{ name => "patent_applicant", type => "text" },

	{ name => "institution", type => "text" },

	{ name => "department", type => "text" },

	{ name => "thesis_type", type => "set", options=>[ "masters", "phd", "other"] },

	{ name => "refereed", type => "boolean", input_style=>"radio" },

	{ name => "isbn", type => "text" },

	{ name => "issn", type => "text" },

	{ name => "fileinfo", type => "longtext",
		render_value=>"render_fileinfo" },

	{ name => "book_title", type => "text" },
	
	{ name => "editors", type => "name", multiple => 1, 
		input_boxes => 4, input_id_cols=>20, 
		family_first=>1, hide_honourific=>1, hide_lineage=>1, allow_null=>1 }, 
	{ name => "editors_id", type => "text", multiple=>1, allow_null=>1, input_cols=>20 },
	{ name => "editors_list", type=>"compound",  multiple=>1,
		fields=>{id=>"editors_id", main=>"editors"} },

	{ name => "official_url", type => "url" },

# nb. Can't call this field "references" because that's a MySQL keyword.
	{ name => "referencetext", type => "longtext", input_rows => 3 },

];

