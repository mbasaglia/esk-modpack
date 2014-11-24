entity xml_load_element(entity prev_sibling, float xmlid, float loadflags);

entity xml_skip_node(entity prev_sibling, float xmlid, float loadflags)
{
	if ( xml_tree_has_sibling(xmlid) )
	{
		xml_tree_next(xmlid);
		return xml_load_element(prev_sibling, xmlid, loadflags);
	}
	return world;
}

entity xml_load_attributes(entity prev_sibling, float xmlid)
{
	if ( xml_tree_type(xmlid) == XML_ATTRIBUTE_NODE )
	{
		entity attr = spawn();
		attr.classname = "xml_attribute";
		attr.xml_prev_sibling = prev_sibling;
		attr.xml_name = strzone(xml_tree_name(xmlid));
		attr.xml_text = xml_tree_text(xmlid);
		if ( attr.xml_text )
			attr.xml_text = strzone( attr.xml_text );
		if ( xml_tree_has_sibling(xmlid) )
		{
			xml_tree_next(xmlid);
			attr.xml_next_sibling = xml_load_attributes(attr,xmlid);
		}
		
		return attr;
	}
	return world;
}

entity xml_load_element(entity prev_sibling, float xmlid, float loadflags)
{
	string class_name;
	switch ( xml_tree_type(xmlid) )
	{
		case XML_ELEMENT_NODE:
			class_name = "xml_element";
			break;
		case XML_TEXT_NODE:
			if ( loadflags & XML_LOADFLAG_TEXT )
				class_name = "xml_text";
			else
				return xml_skip_node(prev_sibling, xmlid, loadflags);
			break;
		case XML_CDATA_SECTION_NODE:
			if ( loadflags & XML_LOADFLAG_TEXT )
				class_name = "xml_cdata";
			else
				return xml_skip_node(prev_sibling, xmlid, loadflags);
			break;
		case XML_COMMENT_NODE:
			if ( loadflags & XML_LOADFLAG_COMMENTS )
				class_name = "xml_comment";
			else
				return xml_skip_node(prev_sibling, xmlid, loadflags);
			break;
		default:
			class_name = "xml_unknown";
			break;
	}
	entity elem = spawn();
	elem.classname = class_name;
	elem.xml_prev_sibling = prev_sibling;
	elem.xml_name = strzone(xml_tree_name(xmlid));
	elem.xml_text = xml_tree_text(xmlid);
	if ( elem.xml_text )
		elem.xml_text = strzone( elem.xml_text );
	if ( xml_tree_attribute(xmlid) )
	{
		elem.xml_first_attribute = xml_load_attributes(world,xmlid);
		xml_tree_parent(xmlid);
	}
	if ( !xml_tree_leaf(xmlid) )
	{
		xml_tree_child(xmlid);
		elem.xml_first_child = xml_load_element(world,xmlid,loadflags);
		xml_tree_parent(xmlid);
	}
	if ( xml_tree_has_sibling(xmlid) )
	{
		xml_tree_next(xmlid);
		elem.xml_next_sibling = xml_load_element(elem,xmlid,loadflags);
	}
	
	return elem;
}

entity xml_load_document( string filename, float loadflags )
{
	float xmlfile = xml_open(filename);
	entity xml_root  = world;
	if ( xmlfile )
	{
		dprint("xmlopen:",ftos(xmlfile),"\n\n");
		xml_root = xml_load_element(world,xmlfile,loadflags);
		xml_close(xmlfile);
		if ( xml_root )
		{
			entity t = xml_root;
			xml_root = spawn();
			xml_root.classname = "xml_document";
			// TODO load encoding and stuff(?)
			xml_root.xml_first_child = t;
			xml_root.xml_name = strzone(filename);
		}
	}
	return xml_root;
}

void xml_cleanup(entity e)
{
	if ( !e )
		return;
	
	xml_cleanup(e.xml_next_sibling);
	xml_cleanup(e.xml_first_child);
	xml_cleanup(e.xml_first_attribute);
	
	if ( e.xml_name )
		strunzone(e.xml_name);
	if ( e.xml_text )
		strunzone(e.xml_text);
	remove(e);
}

void xml_debug_recurse(string prefix, entity e)
{
	dprint(prefix);
	switch ( e.classname )
	{
		case "xml_element":
		case "xml_text":
		case "xml_cdata":
		case "xml_comment":
		case "xml_document":
			dprint("<",e.xml_name);
			dprint(" (",e.classname,") ");
			if ( e.xml_first_attribute )
			{
				dprint("\n");
				xml_debug_recurse(strcat(prefix,"    "),e.xml_first_attribute);
			}
			dprint("> ",e.xml_text,"\n");
			if ( e.xml_first_child )
				xml_debug_recurse(strcat(prefix,"  "),e.xml_first_child);
			if ( e.xml_next_sibling )
				xml_debug_recurse(prefix,e.xml_next_sibling);
			return;
		case "xml_attribute":
			dprint(e.xml_name," = ",e.xml_text,"\n");
			if ( e.xml_next_sibling )
				xml_debug_recurse(prefix,e.xml_next_sibling);
			return;
		default:
			dprint("^1Unknown class:^3 ",e.classname,"\n");
	}
}

void xml_debug(entity doc)
{
	xml_debug_recurse("",doc);
}

string xml_attribute(entity xml_element, string attribute)
{
	entity att;
	for ( att = xml_element.xml_first_attribute; att; att = att.xml_next_sibling )
		if ( att.xml_name == attribute )
			return att.xml_text;
	return string_null;
}