local json = require("json")
print("JSON module type:", type(json))
if json then
  print("decode function:", type(json.decode))
end
