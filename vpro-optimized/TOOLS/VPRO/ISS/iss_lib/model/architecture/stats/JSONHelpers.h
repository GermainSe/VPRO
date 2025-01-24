#ifndef JSONHelpers_H
#define JSONHelpers_H

#define JSON_STRING(val) "\"" << val << "\""
#define JSON_INT(val) (val)
#define JSON_FLOAT(val) (val)

#define JSON_ID(id) JSON_STRING(id) << ":"

#define JSON_OBJ_BEGIN ("{")
#define JSON_OBJ_END ("}")

#define JSON_FIELD_STRING(id, val) JSON_ID(id) << JSON_STRING(val)
#define JSON_FIELD_INT(id, val) JSON_ID(id) << JSON_INT(val)
#define JSON_FIELD_FLOAT(id, val) JSON_ID(id) << JSON_FLOAT(val)
#define JSON_FIELD_OBJ(id) JSON_ID(id) << JSON_OBJ_BEGIN

#endif  //JSONHelpers_H
