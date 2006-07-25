var toggles = new Array();
function doToggle(id)
{
	if(toggles[id]) // Showing
	{
		$(id).style.display = 'none';
		toggles[id] = 0;
	}
	else
	{
		$(id).style.display = '';
		toggles[id] = 1;
	}
}


// this function is needed to work around 
// a bug in IE related to element attributes
function hasClass(obj) 
{
	var result = false;
	if (obj.getAttributeNode("class") != null) 
	{
		result = obj.getAttributeNode("class").value;
	}
	return result;
}   

function highlight(id)
{
	var row = document.getElementById(id);
	var tds = row.getElementsByTagName("td");
	for (var j = 0; j < tds.length; j++) 
	{
		var mytd = tds[j];
		if (!hasClass(mytd) && mytd.style.backgroundColor != "#6078BF") // && !mytd.style.backgroundColor) 
		{
			mytd.style.backgroundColor = "#bfcfff";
		}
	}
}

function select(id)
{
	var row = document.getElementById(id);
	var tds = row.getElementsByTagName("td");
	for (var j = 0; j < tds.length; j++) 
	{
		var mytd = tds[j];
		if (!hasClass(mytd)) // && !mytd.style.backgroundColor) 
		{
			mytd.style.backgroundColor = "#6078BF";
			mytd.style.color = "#fff";
		}
	}
}

function stripe(id) 
{

	var even = false;

	var evenColor = arguments[1] ? arguments[1] : "#fff";
	var oddColor = arguments[2] ? arguments[2] : "#eee";

	var table = document.getElementById(id);
	if (! table) { return; }

	// by definition, tables can have more than one tbody
	// element, so we'll have to get the list of child
	// &lt;tbody&gt;s 
	var tbodies = table.getElementsByTagName("tbody");

	// and iterate through them...
	for (var h = 0; h < tbodies.length; h++) 
	{
		// find all the &lt;tr&gt; elements... 
		var trs = tbodies[h].getElementsByTagName("tr");

		// ... and iterate through them
		for (var i = 0; i < trs.length; i++) 
		{

			// avoid rows that have a class attribute
			// or backgroundColor style
			if (!hasClass(trs[i]) && !trs[i].style.backgroundColor) 
			{
				// get all the cells in this row...
				var tds = trs[i].getElementsByTagName("td");
				
				for (var j = 0; j < tds.length; j++) 
				{
						var mytd = tds[j];

						if (!hasClass(mytd) && mytd.style.backgroundColor != "#6078BF") 
						{
							mytd.style.backgroundColor =
							even ? evenColor : oddColor;
						}
				}
			}
			// flip from odd to even, or vice-versa
			even =  ! even;
		}
	}
}

function MultiSelector( list_target, max ){

	// Where to write the list
	this.list_target = list_target;
	// How many elements?
	this.count = 0;
	// How many elements?
	this.id = 0;
	// Is there a maximum?
	if( max ){
		this.max = max;
	} else {
		this.max = -1;
	};
	
	/**
	 * Add a new file input element
	 */
	this.addElement = function( element ){

		// Make sure it's a file input element
		if( element.tagName == 'INPUT' && element.type == 'file' ){

			// Element name -- what number am I?
			element.name = 'file_' + this.id++;

			// Add reference to this object
			element.multi_selector = this;

			// What to do when a file is selected
			element.onchange = function(){

				// New file input
				var new_element = document.createElement( 'input' );
				new_element.type = 'file';

				// Add new element
				this.parentNode.insertBefore( new_element, this );

				// Apply 'update' to element
				this.multi_selector.addElement( new_element );

				// Update list
				this.multi_selector.addListRow( this );

				// Hide this: we can't use display:none because Safari doesn't like it
				this.style.position = 'absolute';
				this.style.left = '-1000px';
			};
			// If we've reached maximum number, disable input element
			if( this.max != -1 && this.count >= this.max ){
				element.disabled = true;
			};
			// File element counter
			this.count++;
			// Most recent element
			this.current_element = element;
	
		} else {
			// This can only be applied to file input elements!
			alert( 'Error: not a file input element' );
		};

	};

	/**
	 * Add a new row to the list of files
	 */
	this.addListRow = function( element ){

		// Row div
		var new_row = document.createElement( 'tr' );
		new_row.setAttribute("onMouseOver", "highlight('tr"+this.count+"')");
		new_row.setAttribute("onMouseOut", "stripe('filelist', '#fff', '#e6f6ff')");
		new_row.setAttribute("id", "tr"+this.count);
		
		var file_name = document.createElement( 'td' );
		var file_prim = document.createElement( 'td' );
		file_prim.setAttribute('align', 'center');
		var file_inp = document.createElement( 'input' );
		file_inp.setAttribute( 'type', 'radio' );
		file_inp.setAttribute( 'name', 'file_prim' );
		if( this.count == 2 ) file_inp.setAttribute( 'checked', '1' );
		file_prim.appendChild( file_inp );
		new_row.appendChild( file_name );
		new_row.appendChild( file_prim );
		
		file_name.innerHTML = element.value;
		// Add it to the list
		this.list_target.appendChild( new_row );
		stripe('filelist', '#fff', '#e6f6ff');		
	};

};
