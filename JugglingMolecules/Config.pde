/*******************************************************************
 *	VideoAlchemy "Juggling Molecules" Interactive Light Sculpture
 *	(c) 2011-2013 Jason Stephens & VideoAlchemy Collective
 *
 *	See `credits.txt` for base work and shouts out.
 *	Published under CC Attrbution-ShareAlike 3.0 (CC BY-SA 3.0)
 *		            http://creativecommons.org/licenses/by-sa/3.0/
 *******************************************************************/

////////////////////////////////////////////////////////////
//  Configuration base class.
//
//  We can load and save these to disk to restore "interesting" states to play with.
//
//	Configurations are stored in ".config" files in Tab-Separated-Value format.
//		We have a header row as 		field<tab>value
//		and then each row of data is 	<field><tab><value>
//										<field><tab><value>
//
//	We can auto-parse these config files using reflection.
//
////////////////////////////////////////////////////////////

//import java.lang.reflect.Field;
import java.lang.reflect.*;


// Internal "logical data types" we understand.
int _UNKNOWN_TYPE	= 0;
int _INT_TYPE 		= 1;
int _FLOAT_TYPE 	= 2;
int _BOOLEAN_TYPE 	= 3;
int _COLOR_TYPE 	= 4;
int _STRING_TYPE 	= 5;



class Config {

	// constructor
	public Config() {}

	// Set to true to print debugging information if something goes wrong
	//	which would normally be swallowed silently.
	boolean debugging = false;

	// List of "setup" fields.
	// These will be loaded/saved in "config/setup.config" and will be loaded
	//	BEFORE initialization begins (so you can have dynamic screen size, etc).
	static String[] SETUP_FIELDS = {"windowWidth", "windowHeight", "kinectAngle", "activeConfig"};

	// List of "default" fields.
	// These will be loaded/saved in "config/defaults.config" and will be loaded
	//	at startup BEFORE the "main" config file is loaded.
	// Put your "MIN_" and "MAX_" constants in here.
	static String[] DEFAULT_FIELDS = {};

	// Names of all of our "normal" configuration fields.
	// These are what are actually saved per each configuration.
	static String[] FIELDS = {};


////////////////////////////////////////////////////////////
//	Config file path.  Use  `getFilePath()` to get the full path.
//	as:  <filepath>/<filename>.tsv
////////////////////////////////////////////////////////////

	// Path to ALL config files for this type, local to sketch directory.
	// The path will be created if necessary.
	// DO NOT include the trailing slash.
	static String filepath = "config/";


	// Extension (including period) for all files of this type.
	static String extension = ".config";


	// Name of this individual config file.
	// This is generally set by `load()`ing or `save()`ing.
	// DO NOT include the path or extension!
	String filename;


	// Return the full path for a given config file instance.
	// If you pass `_filename`, we'll use that.
	// Otherwise we'll use our internal `filename` (but won't set it).
	// Returns `null` if no filename specified.
	String getFilePath(String _filename) {
		if (_filename == null) _filename = filename;
		if (_filename == null) {
			this.error("ERROR in config.getFilePath(): no filename specified.");
			return null;
		}
		return filepath + "/" + _filename + extension;
	}


////////////////////////////////////////////////////////////
//	Dealing with change.
////////////////////////////////////////////////////////////

	// One of our fields has changed.
	// Do something!  Tell somebody!
	void fieldChanged(String fieldName) {}


////////////////////////////////////////////////////////////
//	Loading from disk and parsing.
////////////////////////////////////////////////////////////

	// Load configuration from data stored on disk.
	// If you pass `_filename`, we'll load from that file and remember as our `filename` for later.
	// If you pass null, we'll use our stored `filename`.
	// Returns `changeLog` Table of actual changed values.
	Table load(String _filename) {
		// remember filename if
		if (_filename != null) this.filename = _filename;
		String path = getFilePath();
		if (path == null) {
			this.error("ERROR in config.loadFromConfigFile(): no filename specified");
			return;
		}

		this.showDebug("Attempting to read config from file "+path);
		this.showDebug("Current values:");
		if (this.debugging) this.echo();

		// load as a .tsv file with loadTable()
		Table inputTable = loadTable(path, "header,tsv");

		// make a table to hold changes found while setting values
		Table changeLog = makeFieldTable();

		// iterate through our inputTable, updating our fields
		for (TableRow row : inputTable.rows()) {
			String fieldName = row.getString("field");
			String value 	 = row.getString("value");
			String typeHint	 = row.getString("type");
			this.setField(fieldName, value, typeHint, changeLog);
		}

	// TODO: send changeLog to our controllers (or possibly all values?)

		// print out the config
		this.showDebug("Finished reading config!  New values:");
		if (this.debugging) this.echo();
		return changeLog;
	}


	// Parse a single field/value pair from our config file and update the corresponding value.
	// Eats all exceptions.
	void setField(String fieldName, String stringValue) {
		this.setField(fieldName, stringValue, null, null);
	}
	void setField(String fieldName, String stringValue, String typeHint) {
		this.setField(fieldName, stringValue, typeHint, null);
	}
	void setField(String fieldName, String stringValue, String typeHint, Table changeLog) {
		Field field = this.getField(fieldName, "setField({{fieldName}}): field not found");
		this.setField(field, stringValue, typeHint, changeLog);
	}

	void setField(Field field, String stringValue, String typeHint, Table changeLog) {
		int type = this.getType(field, typeHint);
		try {
			switch (type) {
				case _INT_TYPE:		this.setInt(field, stringValue, changeLog); return;
				case _FLOAT_TYPE:	this.updateFloatFieldWithString(field, stringValue, changeLog); return;
				case _BOOLEAN_TYPE:	this.updateBooleanFieldWithString(field, stringValue, changeLog); return;
				case _COLOR_TYPE:	this.updateColorFieldWithString(field, stringValue, changeLog); return;
				case _STRING_TYPE:	this.updateStringFieldWithString(field, stringValue, changeLog); return;
				default:			break;
		} catch (exception e) {
			this.debug("parseConfigField("+fieldName+"): error while updating field value.  Skipping.");
		}
	}


	// set an integer field.
	boolean setInt(String fieldName, String stringValue) {
		return this.setInt(fieldName, stringValue, null);
	}
	boolean setInt(String fieldName, String stringValue, Table changeLog) {
		Field field = this.getField(fieldName, "setInt({{fieldName}}: field not found.");
		return this.setInt(field, stringValue, changeLog);
	}
	boolean setInt(Field field, String stringValue, Table changeLog) {
		if (field == null) return false;
		try {
			int oldValue = field.getInt(this);
			int newValue = stringToInt(stringValue);
			if (oldValue != newValue) {
				field.setInt(this, newValue);
				if (changeLog) {
					TableRow row = changeLog.addRow();
					row.setString("field", field.getName());
					row.setString("type" , getTypeName(_INT_TYPE);
					row.setString("value", ""+field.getInt(this));
				} else {
					this.fieldChanged(field.getName());
				}
			}
		} catch (Exception e) {
			this.warn("setInt("+field.getName()+"): exception setting string value '"+stringValue+"'", e);
		}
		return false;
	}


	// Update an integer field on our object by coercing the specified `stringValue`.
	// Returns the parsed value.  Will throw if something goes wrong.
	int updateIntFieldWithString(String fieldName, String stringValue, String typeHint, Table changeLog) throws Exception {
		Field field Config.class.getDeclaredField(fieldName);
		return updateIntFieldWithString(field, stringValue, changeLog);
	}
	int updateIntFieldWithString(Field field, String stringValue, String typeHint, Table changeLog) throws Exception {
		// HACK: if stringValue starts with "color(", assume it's a color and process accordingly.
		if (stringValue.startsWith("color(")) return updateColorFieldWithString(field, stringValue);

		int oldValue = field.getInt(this);
		int newValue = int(stringValue);
		if (oldValue != newValue) {
			this.showDebug("parsed int "+field.getName()+" value to "+newValue);
			field.setInt(this, newValue);
			if (changeLog) {
				TableRow row = changeLog.addRow();
				row.setString("field", field.getName());
				row.setString("type" , getTypeName(_INT_TYPE);
				row.setString("value", stringFromInt(field);
			}
		}
		return newValue;
	}

	// Update a boolean field on our object by coercing the specified `stringValue`.
	// Returns the parsed value.  Will throw if something goes wrong.
	boolean updateBooleanFieldWithString(String fieldName, String stringValue, Table changeLog) throws Exception {
		Field field Config.class.getDeclaredField(fieldName);
		return updateBooleanFieldWithString(field, stringValue, changeLog);
	}
	boolean updateBooleanFieldWithString(Field field, String stringValue, Table changeLog) throws Exception {
		boolean oldValue = field.getBoolean(this);
		boolean newValue = boolean(stringValue);
		if (oldValue != newValue) {
			this.showDebug("parsed boolean "+field.getName()+" value to "+newValue);
			field.setBoolean(this, newValue);
			if (changeLog) {
				TableRow row = changeLog.addRow();
				row.setString("field", field.getName());
				row.setString("type" , getTypeName(_BOOLEAN_TYPE);
				row.setString("value", stringFromBoolean(field);
			}
		}
		return newValue;
	}

	// Update a float field on our object by coercing the specified `stringValue`.
	// Returns the parsed value.  Will throw if something goes wrong.
	float updateFloatFieldWithString(String fieldName, String stringValue, Table changeLog) throws Exception {
		Field field Config.class.getDeclaredField(fieldName);
		return updateFloatFieldWithString(field, stringValue, changeLog);
	}
	float updateFloatFieldWithString(Field field, String stringValue, Table changeLog) throws Exception {
		float oldValue = field.getFloat(this);
		float newValue = float(stringValue);
		if (oldValue != newValue) {
			this.showDebug("parsed float "+field.getName()+" value to "+newValue);
			field.setFloat(this, newValue);
			if (changeLog) {
				TableRow row = changeLog.addRow();
				row.setString("field", field.getName());
				row.setString("type" , getTypeName(_FLOAT_TYPE);
				row.setString("value", stringFromFloat(field);
			}
		}
		return newValue;
	}

	// Update an color field on our object by coercing the specified `stringValue`.
	// Returns the parsed value.  Will throw if something goes wrong.
	color updateColorFieldWithString(String fieldName, String stringValue, Table changeLog) throws Exception {
		Field field Config.class.getDeclaredField(fieldName);
		return updateIntFieldWithString(field, stringValue, changeLog);
	}
	color updateColorFieldWithString(Field field, String stringValue, Table changeLog) throws Exception {
		int oldValue = field.getInt(this);
		int newValue = (int) getColorFieldValue(stringValue);
		if (oldValue != newValue) {
			this.showDebug("parsed int "+field.getName()+" value to "+newValue);
			field.setInt(this, newValue);
			if (changeLog) {
				TableRow row = changeLog.addRow();
				row.setString("field", field.getName());
				row.setString("type" , getTypeName(_COLOR_TYPE);
				row.setString("value", stringFromColor(field);
			}
		}
		return (color) newValue;
	}

	// Update a string field on our object.
	// Returns the parsed value.  Will throw if something goes wrong.
	String updateStringFieldWithString(String fieldName, String stringValue, Table changeLog) throws Exception {
		Field field Config.class.getDeclaredField(fieldName);
		return updateStringFieldWithString(field, stringValue, null);
	}
	String updateStringFieldWithString(Field field, String stringValue) throws Exception {
		return updateStringFieldWithString(field, stringValue, null);
	}
	String updateStringFieldWithString(Field field, String newValue) throws Exception {
		String oldValue = field.get(this);
		if (oldValue == null || !oldValue.equals(newValue)) {
			this.showDebug("updating string "+field.getName()+" value to "+newValue);
			field.set(this, newValue);
			this.fieldChanged(field.getName(), newValue, oldValue);
		}
		return newValue;
	}


////////////////////////////////////////////////////////////
//	Saving to disk.
////////////////////////////////////////////////////////////

	// Save the FIELDS in our current config to a file.
	// If you pass `_fileName`, we'll use that file (and remember it for later).
	// Otherwise we'll
	void save(String _fileName) {
		if (_filename != null) this.filename = _filename;
		String path = getFilePath();
		if (path == null) {
			if (this.debugging) println("ERROR in config.saveToFile(): no filename specified");
			return;	// TOTHROW ???
		}

		// Get the data as a table
		Table table = getFieldsAsTable(FIELDS, null);

// TODO: update our (controllers? observers?) with the new data
// 		 NOTE: we want to do this BEFORE writing to the file
//		 as saveTableAs() will munge the table...

		// Write to the file.
		saveTableAs(path, table);
	}

	// Given a table in our format, save it to a file.
	void saveTableAs(String path, Table table) {
		// Write to the file.
		saveTable(path, table);
	}

	// Create a new table for this config class which is set up to go.
	Table makeFieldTable() {
		Table table = new Table();
		table.addColumn("type");		// field type (eg: "int" or "string" or "color")
		table.addColumn("field");		// name of the field
		table.addColumn("value");		// string value for the field
		return table;
	}

	// Return output for a set of fieldNames as a Table with columns:
	//		"type", "field", (stringified) "value"
	// If you pass a Table, we'll add to that, otherwise we'll create a new one.
	// Eats exceptions.
	Table getFieldsAsTable(String[] fieldNames, Table table) {
		if (fieldNames == null) fieldNames = FIELDS;

		// if we weren't passed a table, create one now
		if (table == null) table = makeFieldTable();
		if (fieldNames == null) return table;

		for (String fieldName : fieldNames) {
			try {
				// add row up front, we'll remove it in the exception handler if something goes wrong
				TableRow row = table.addRow();

				// get the field definition
				Field field = getField(fieldName);
				row.setString("field", fieldName);

				// get the type of the field
				int type = getType(field);
				if (type == _UNKNOWN_TYPE) new NoSuchFieldException();
				row.setString("type", getTypeName(type));

				switch (type) {
					case _INT_TYPE:		row.setString("value", 	this.stringFromInt(field));
										break;

					case _FLOAT_TYPE:	row.setString("value", 	this.stringFromFloat(field));
										break;

					case _BOOLEAN_TYPE:	row.setString("value", 	this.stringFromBoolean(field));
										break;

					case _COLOR_TYPE:	row.setString("value",  this.stringFromColor(field));
										break;

					case _STRING_TYPE:	row.setString("value",	this.stringFromString(field));
										break;
					default:
						if (this.debugging) println("Don't know what to do with type of field "+fieldName);
				}
			} catch (Exception e) {
				if (this.debugging) println("getFieldsAsTable(): error processing field "+fieldName);
				// remove the incomplete row
				table.removeRow(table.getRowCount()-1);
			}
		}
		return table;
	}


////////////////////////////////////////////////////////////
//	Reflection methods
////////////////////////////////////////////////////////////

	////////////////////////////////////////////////////////////
	//	Getting field definitions.
	////////////////////////////////////////////////////////////

	// Return the Field definition for a named field.
	// Returns null if no field can be found.
	// Swallows all exceptions.
	Field getField(String fieldName) {
		try {
//TODO: how to genericise this to current class?
			return Config.class.getDeclaredField(fieldName);
		} catch (Exception e){
			return null;
		}
	}

	// Return the field definition for a named field, printing a debug message if not found.
	//
	// If field cannot be found, we'll:
	//	- print debug message (with "{{fieldName}}" replaced with the name of the field), and
	//	- return null.
	Field getField(String fieldName, String message) {
		Field field = this.getField(fieldName);
		if (field == null && message != null) {
			this.debug(message.replace("{{fieldName}}", fieldName));
		}
		return field;
	}

	////////////////////////////////////////////////////////////
	//	Getting "logical" field types.
	////////////////////////////////////////////////////////////

	// Return the "logical" data type for a field, specified by `fieldName` or by `field`,
	//	eg: `_INT_TYPE` or `_FLOAT_TYPE`
	// If you have a `typeHint` (eg: from a tsv file), pass that, it might help.
	// Returns `_UNKNOWN_TYPE` if we can't find the field or it's not a type we understand.
	// Swallows all exceptions.
	int getType(String fieldName) { return this.getType(getField(fieldName), null); }
	int getType(String fieldName, String typeHint) { return this.getType(getField(fieldName), typeHint); }
	int getType(Field field) { return this.getType(field, null); }
	int getType(Field field, String typeHint) {
		if (field == null) return _UNKNOWN_TYPE;
//TODO: how best to genericise this???  some type of MAP ???
		if (typeHint != null && typeHint.equals("color")) return _COLOR_TYPE;

		Type type = field.getType();
		if (type == Integer.TYPE) {
			// Ugh.  Processing masquerades `color` variables as `int`s.
			// If the field name ends with "Color", assume it's a color.
//TODO: how best to genericise this???
			field.getName().endsWith("Color")) return _COLOR_TYPE;
			return _INT_TYPE;
		}
		if (type == Float.TYPE) 	return _FLOAT_TYPE;
		if (type == Boolean.TYPE) 	return _BOOLEAN_TYPE;
		if (type == String.TYPE)	return _STRING_TYPE;
		return _UNKNOWN_TYPE;
	}

	// Return our logical 'name' for each `type`.
	String getTypeName(int type) {
		switch(type) {
			case _INT_TYPE:		return "int";
			case _FLOAT_TYPE:	return "float";
			case _BOOLEAN_TYPE:	return "boolean";
			case _COLOR_TYPE:	return "color";
			case _STRING_TYPE:	return "string";
			default:			return "UNKNOWN";
		}
	}


////////////////////////////////////////////////////////////
//	Return internal value for a given field, specified by field name or Field.
// 	They will throw:
//		- `NoSuchFieldException` if no field found with that name, or
//		- `IllegalArgumentException` if we can't parse the value.
////////////////////////////////////////////////////////////

	int getInt(String fieldName) throws Exception {return this.getInt(getField(fieldName));}
	int getInt(Field field) throws Exception {
		if (field == null) throw new NoSuchFieldException();
		return field.getInt(this);
	}
	float getFloat(String fieldName) throws Exception {return this.getFloat(getField(fieldName));}
	float getFloat(Field field) throws Exception {
		if (field == null) throw new NoSuchFieldException();
		return field.getFloat(this);
	}
	boolean getBoolean(String fieldName) throws Exception {return this.getBoolean(getField(fieldName));}
	boolean getBoolean(Field field) throws Exception {
		if (field == null) throw new NoSuchFieldException();
		return field.getBoolean(this);
	}
	color getColor(String fieldName) throws Exception {return this.getColor(getField(fieldName));}
	color getColor(Field field) throws Exception {
		if (field == null) throw new NoSuchFieldException();
		return (color)field.getInt(this);
	}
	String getString(String fieldName) throws Exception {return this.getString(getField(fieldName));}
	String getString(Field field) throws Exception {
		if (field == null) throw new NoSuchFieldException();
		return (String) field.get(this);
	}


////////////////////////////////////////////////////////////
//	Return internal values for a given field, returning `defaultValue` on exception.
//	Swallows all exceptions.
////////////////////////////////////////////////////////////

	// Get internal int value.
	int getInt(String fieldName, int defaultValue) {
		Field field = this.getField(fieldName, "getInt({{fieldName}}: field not found.  Returning default: "+defaultValue);
		return getInt(field, defaultValue);
	}
	int getInt(Field field, int defaultValue) {
		if (field == null) return defaultValue;
		try {
			return field.getInt(this);
		} catch (Exception e) {
			this.warn("getInt("+field.getName()+"): error getting int value.  Returning default "+defaultValue, e);
			return defaultValue;
		}
	}

	// Get internal float value.
	float getFloat(String fieldName, float defaultValue) {
		Field field = this.getField(fieldName, "getFloat({{fieldName}}: field not found.  Returning default: "+defaultValue);
		return getFloat(field, defaultValue);
	}
	float getFloat(Field field, float defaultValue){
		if (field == null) return defaultValue;
		try {
			return field.getFloat(this);
		} catch (Exception e) {
			this.warn("getFloat("+field.getName()+"): error getting float value.  Returning default "+defaultValue, e);
			return defaultValue;
		}
	}

	// Get internal boolean value.
	boolean getBoolean(String fieldName, boolean defaultValue) {
		Field field = this.getField(fieldName, "getBoolean({{fieldName}}: field not found.  Returning default: "+defaultValue);
		return getBoolean(field, defaultValue);
	}
	boolean getBoolean(Field field, boolean defaultValue){
		if (field == null) return defaultValue;
		try {
			return field.getBoolean(this);
		} catch (Exception e) {
			this.warn("getBoolean("+field.getName()+"): error getting boolean value.  Returning default "+defaultValue, e);
			return defaultValue;
		}
	}

	// Get internal color value.
	color getColor(String fieldName, color defaultValue) {
		Field field = this.getField(fieldName, "getColor({{fieldName}}: field not found.  Returning default: "+defaultValue);
		return getColor(field, defaultValue);
	}
	color getColor(Field field, color defaultValue){
		if (field == null) return defaultValue;
		try {
			return (clor) field.getInt(this);
		} catch (Exception e) {
			this.warn("getColor("+field.getName()+"): error getting color value.  Returning default "+defaultValue, e);
			return defaultValue;
		}
	}

	// Get internal string value.
	String getString(String fieldName, String defaultValue) {
		Field field = this.getField(fieldName, "getString({{fieldName}}: field not found.  Returning default: "+defaultValue);
		return getString(field, defaultValue);
	}
	String getString(Field field, String defaultValue){
		if (field == null) return defaultValue;
		try {
			return (clor) field.getInt(this);
		} catch (Exception e) {
			this.warn("getString("+field.getName()+"): error getting String value.  Returning default "+defaultValue, e);
			return defaultValue;
		}
	}



////////////////////////////////////////////////////////////
//	Coercing native field value to our string equivalent.
//	Returns `null` on exception.
////////////////////////////////////////////////////////////

	// Return the value for one of our fields, specified by `fieldName` or `field`.
	String fieldToString(String fieldName) {
		Field field = this.getField(fieldName, "fieldToString({{fieldName}}: field not found.");
		return this.fieldToString(this.getField(fieldName));
	}
	String fieldToString(String fieldName, int type) {
		Field field = this.getField(fieldName, "fieldToString({{fieldName}}: field not found.");
		return this.fieldToString(this.getField(fieldName), type);
	}
	String fieldToString(Field field) {
		if (field == null) return null;
		try {
			int type = this.getType(field);
		} catch (Exception e) {
			this.warn("fieldToString(field "+field.getName()+"): exception getting type value.  Returning null.");
			return null;
		}
		return this.typedFieldToString(field, type);
	}

	// Given a Field record and a corresponding "logical" `type"
	//	return the current value of that field as a String.
	String typedFieldToString(Field field, int type) {
		if (field == null) return null;
		switch (type) {
			case _INT_TYPE:		return this.intFieldToString(field);
			case _FLOAT_TYPE:	return this.floatFieldToString(field);
			case _BOOLEAN_TYPE:	return this.booleanFieldToString(field);
			case _COLOR_TYPE:	return this.colorFieldToString(field);
			case _STRING_TYPE:	return this.stringFieldToString(field);
			default:
				this.warn("typedFieldToString(field "+field.getName()+" field type '"+type+"' not understood");
		}
		return null;
	}

////////////////////////////////////////////////////////////
//	Coercing native field value to our string equivalent.
//	Returns `null` on exception.
////////////////////////////////////////////////////////////

	// Return string value for integer field.
	String intFieldToString(String fieldName) {
		Field field = this.getField(fieldName, "intFieldToString({{fieldName}}): field not found.");
		return this.intFieldToString(field);
	}
	String intFieldToString(Field field) {
		try {
			return this.intToString(field.getInt(this));
		} catch (Exception e) {
			this.warn("intFieldToString(field "+field.getName()+"): returning null", e);
			return null;
		}
	}

	// Return string value for float field.
	String floatFieldToString(String fieldName) {
		Field field = this.getField(fieldName, "floatFieldToString({{fieldName}}): field not found.");
		return this.floatFieldToString(field);
	}
	String floatFieldToString(Field field) {
		try {
			return this.floatToString(field.getFloat(this));
		} catch (Exception e) {
			this.warn("floatFieldToString(field "+field.getName()+"): returning null", e);
			return null;
		}
	}

	// Return string value for boolean field.
	String booleanFieldToString(String fieldName) {
		Field field = this.getField(fieldName, "booleanFieldToString({{fieldName}}): field not found.");
		return this.booleanFieldToString(field);
	}
	String booleanFieldToString(Field field) {
		try {
			boolean isTrue = field.getBoolean(this);
			return (isTrue ? "true" : "false");
		} catch (Exception e) {
			this.warn("booleanFieldToString(field "+field.getName()+"): returning null", e);
			return null;
		}
	}

	// Return string value for color field.
	String colorFieldToString(String fieldName) {
		Field field = this.getField(fieldName, "colorFieldToString({{fieldName}}): field not found.");
		return this.colorFieldToString(field);
	}
	String colorFieldToString(Field field) {
		try {
			color value = (color)field.getInt(this);
			return "color("+(int)red(value)+","+(int)green(value)+","+(int)blue(value)+","+(int)alpha(value)+")";
		} catch (Exception e) {
			this.warn("colorFieldToString(field "+field.getName()+"): returning null");
			return null;
		}
	}

	// Return string value for string field.  :-)
	String stringFieldToString(String fieldName) {
		Field field = this.getField(fieldName, "stringFieldToString({{fieldName}}): field not found.");
		return this.stringFieldToString(field);
	}
	String stringFieldToString(Field field) {
		try {
			return (String) field.get(this);
		} catch (Exception e) {
			this.warn("stringFieldToString("+field.getName()+"): returning null");
			return null;
		}
	}




////////////////////////////////////////////////////////////
//	Given a native data type, return the equivalent String value.
//	Returns null on exception.
////////////////////////////////////////////////////////////

	// Return string value for integer.
	String intToString(int value) {
		try {
			return ""+value;
		} catch (Exception e) {
			this.warn("intToString(): returning null", e);
			return null;
		}
	}

	// Return string value for float field.
	String floatToString(float value) {
		try {
			return ""+value;
		} catch (Exception e) {
			this.warn("floatToString("+field.getName()+"): returning null", e);
			return null;
		}
	}

	// Return string value for boolean value.
	String booleanToString(boolean value) {
		try {
			return (value ? "true" : "false");
		} catch (Exception e) {
			this.warn("booleanToString("+field.getName()+"): returning null", e);
			return null;
		}
	}

	// Return string value for color value.
	String colorToString(color value) {
		try {
			return "color("+(int)red(value)+","+(int)green(value)+","+(int)blue(value)+","+(int)alpha(value)+")";
		} catch (Exception e) {
			this.warn("ERROR in colorToString("+field.getName()+"): returning null", e);
			return null;
		}
	}

	// Return string value for string (base case).
	String stringToString(String string) {
		return string;
	}





////////////////////////////////////////////////////////////
//	Given a String representation of a native data type,
//		return the equivalent data type.
//	Returns throws on exception.
////////////////////////////////////////////////////////////

	int stringToInt(String stringValue) throws Exception {
		return int(stringValue);
	}

	float stringToFloat(String stringValue) throws Exception {
		return float(value);
	}

	boolean stringToBoolean(String stringValue) throws Exception {
		return (stringValue.equals("true") ? true : false);
	}

	color stringToColor(String stringValue) throws Exception {
		String[] colorMatch = match(stringValue, "[color|rgba]\\((\\d+?)\\s*,\\s*(\\d+?)\\s*,\\s*(\\d+?)\\s*,\\s*(\\d+?)\\)");
		if (colorMatch == null) throw new Exception();	// TODO: more specific...
// TODO: variable # of arguments
// TODO: #FFCCAA
		int r = int(colorMatch[1]);
		int g = int(colorMatch[2]);
		int b = int(colorMatch[3]);
		int a = int(colorMatch[4]);
		this.debug("parsed color color("+r+","+g+","+b+","+a+")");
		return color(r,g,b,a);
	}







////////////////////////////////////////////////////////////
//	Debugging and error handling.
////////////////////////////////////////////////////////////

	// Log a debug message -- something unexpected happened, but no biggie.
	void debug(message) {
		if (this.debugging) println(message);
	}


	// Log a warning message -- something unexpected happened, but it's not fatal.
	void warn(message) {
		this.warn(message, null);
	}

	void warn(message, Exception e) {
		if (!this.debugging) return;
		println("WARNING: " + message);
		if (e) println(e);
	}

	// Log an error message -- something unexpected happened, and it's pretty bad.
	void error(message) {
		this.error(message, null);
	}

	void error(message, Exception e) {
		if (!this.debugging) return;
		println("ERROR!!:   " + message);
		if (e) println(e);
	}


}