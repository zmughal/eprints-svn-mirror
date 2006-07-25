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
