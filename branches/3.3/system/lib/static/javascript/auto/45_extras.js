/* serialise a form excluding all 'submit', 'image' and 'button' values */
function serialize_form(form) {
	var inputs = form.select ('input[type="image"]', 'input[type="button"]');
	inputs.invoke ('disable');

	var params = form.serialize({
		hash: true,
		submit: false
	});

	inputs.invoke ('enable');

	return params;
}

// http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
function generate_uuid()
{
	var s = [];
	var hexDigits = "0123456789ABCDEF";
	for(var i = 0; i < 32; i++)
		s[i] = hexDigits.substr(Math.floor(Math.random() * 0x10), 1);
	s[12] = "4";
	s[16] = hexDigits.substr((s[16] & 0x3) | 0x8, 1);

	return s.join("");
}

Element.addMethods({
  attributesHash: function(element) {
                var attr = element.attributes;
	        var h = $H ();
		
		if( typeof NamedNodeMap == 'object' )
		{
        		for (var i = 0; i < attr.length; ++i)
		                h[attr[i].name] = attr[i].value;
		}
		else
		{
        	        for( var i=0;i<attr.length; ++i)
                	        h[attr[i]] = element.getAttribute( attr[i] );
		}
	                
		return h;
  }
});
