// http://ijosblog.blogspot.fi/2012/08/opa-language-tutorial-part-4.html

type regexExpression = { string exprID, string regex, string description };

database regexDB {
   stringmap(regexExpression) /expressions
}

function hello()
{
   Resource.styled_page("Expressions Server - Hello", ["/resources/css.css"],
      <div>
         This server contains various regular expressions for data analysis either presented individually or by grouping and returned as JSON objects via the REST interface. See API documents for more information
       </> );
}


function error()
{
   Resource.styled_page("Expressions Server - Error", ["/resources/css.css"],
      <div>
          No idea of what you want, go read the API documents for the web and REST/JSON interfaces, or better still go read the source code!
      </> );
}

function messageSuccess(m,c)
{
    Resource.raw_response(
      OpaSerialize.serialize({ success:m }),
      "application/json",
      c
    )
}

function messageError(m,c)
{
    Resource.raw_response(
      OpaSerialize.serialize({ error:m }),
      "application/json",
      c
     )
}

function expressionsPost()
{
  match(HttpRequest.get_body())
  {
  case{some: body}:
    match(Json.deserialize(body))
    {
       case{some: jsonobject}:
          match(OpaSerialize.Json.unserialize_unsorted(jsonobject))
          {
             case{some: regexExpression e}:
                /regexDB/expressions[e.exprID] <- e;
                messageSuccess("{e.exprID}",{created});
             default:
                messageError("Missing or malformed fields",{bad_request});
          }
       default:
          messageError("Failed to deserialised the JSON",{bad_request});
    }
  default:
     messageError("Missing body",{bad_request});
  }
}

function expressionsGet()
{
   Resource.raw_response(
      OpaSerialize.serialize({expressions:
                                    List.map(
                                       function(i) { i.exprID },
                                       StringMap.To.val_list(/regexDB/expressions) )
                             }),
      "application/json",
     {success}
     )
}

function expressionGetWithKey(key)
{
    match(?/regexDB/expressions[key])
    {
       case {none}:
          messageError("No entry for with id {key} exists",{bad_request});
       case {some: r}:
          Resource.raw_response(
             OpaSerialize.serialize(r),
             "application/json",
             {success}
          );
    }
}

function expressionPutWithKey(key)
{
 match(HttpRequest.get_body())
 {
  case {some: body}:
    match(?/regexDB/expressions[key])
    {
       case {none}:
          messageError("No entry for with id {key} exists",{success});
       case {some: k}:
           match(Json.deserialize(body))
           {
                case{some: jsonobject}:
                    match(OpaSerialize.Json.unserialize_unsorted(jsonobject))
                    {
                      case{some: regexExpression e}:
                         if (e.exprID == key)
                         {
                            /regexDB/expressions[e.exprID] <- e;
                            messageSuccess("Expression with key {e.exprID} modified",{success});
                         }
                         else
                         {
                            messageError("Attempt to update failed",{bad_request});
                         }
                      default:
                         messageError("Missing or malformed fields",{bad_request});
                    }
                 default:
                       messageError("No valid JSON in body of PUT",{bad_request});
               }
           }
   default:
      messageError("No body in PUT",{bad_request});
 }
}

function expressionDeleteWithKey(key)
{
    match(?/regexDB/expressions[key])
    {
       case {none}:
          messageError("No entry for with id {key} exists",{bad_request});
       case {some: r}:
          Db.remove(@/regexDB/expressions[key]);
          messageSuccess("{key} removed",{success});
    }
}

function expressionsRESTendpoint()
{
   match(HttpRequest.get_method())
   {
      case{some: method}:
         match(method)
         {
             case{get}:
                expressionsGet();
             case{post}:
                expressionsPost();
             case{put}:
                messageError("PUT method not allowed without a key",{bad_request});
             case{delete}:
                messageError("DELETE method not allowed without a key",{bad_request});
             default:
                messageError("Given REST Method not allowed with expressions",{bad_request});                  }
      default:
          messageError("Error in the HTTP request",{bad_request});
   }
}

function expressionWithKeyRESTendpoint(key)
{
   match(HttpRequest.get_method())
   {
      case{some: method}:
         match(method)
         {
             case{get}:
                expressionGetWithKey(key);
             case{post}:
                messageError("POST method not allowed with a key",{bad_request});
             case{put}:
                expressionPutWithKey(key);
             case{delete}:
                expressionDeleteWithKey(key);
             default:
                messageError("Given REST Method not allowed with expressions with keys",{bad_request});
         }
      default:
          messageError("Error in the HTTP request",{bad_request});
   }
}

start = parser
{
       case "/": hello();
       case "/expressions" : expressionsRESTendpoint();
       case "/expressions/" key=((!"/".)*) (.*): expressionWithKeyRESTendpoint(Text.to_string(key));
       default: error();
}

Server.start(
   Server.http,
     [ {resources: @static_include_directory("resources")} , {custom: start} ]
);