# frozen_string_literal: true

require 'json'
require 'jwt'
require 'pp'

def main(event:, context:)
  # You shouldn't need to use context, but its fields are explained here:
  # https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html
  if event["path"]!='/' && event["path"]!='/token'
    return response(status:404)
  end
  if event["httpMethod"] == "GET"
    return GETHandler(event)
  elsif event["httpMethod"] == "POST"
    return POSTHandler(event)
  else
    return response(status:405)
  end
end

def POSTHandler(body)
  if body["path"]!='/token'
    return response(status:405) # path is '/token'
  end
  if body["headers"]["Content-Type"]!="application/json"
    return response(body:{"type":body["headers"]["Content-Type"]},status:415)
  end
  begin
    content = JSON.parse(body["body"])
  rescue
    content = nil
  if cotent.nil?
    return response(status:422)
  end
  payload = {
    data: content,
    exp: Time.now.to_i + 5,
    nbf: Time.now.to_i + 2
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  return response(body:{"token":token},status:201)
  
end

def GETHandler(body)
  if body["path"]!="/"
    return response(status:405) # path is '/'
  end
  token = body["headers"]["Authorization"] rescue nil
  if token.nil?
    return response(status:403)
  end
  if !(token.match(/^Bearer /))
    return response(status:403)
  end
  #return response(body:{"token":token[7..-1]},status:200)
  begin
    token = JWT.decode token[7..-1], ENV['JWT_SECRET'], true, { algorithm: 'HS256' }
  rescue
    token = nil
  if token.nil?
    return response(status:403)
  end
  payload = token[0]
  if payload['exp'] < Time.now.to_i || payload['nbf']> Time.now.to_i
    return response(status:401)
  end
  return response(body:payload['data'],status:200)
  
end

def response(body: nil, status: 200)
  {
    body: body ? body.to_json + "\n" : '',
    statusCode: status
  }
end

if $PROGRAM_NAME == __FILE__
  # If you run this file directly via `ruby function.rb` the following code
  # will execute. You can use the code below to help you test your functions
  # without needing to deploy first.
  ENV['JWT_SECRET'] = 'NOTASECRET'

  # Call /token
  PP.pp main(context: {}, event: {
               'body' => '{"name": "bboe"}',
               'headers' => { 'Content-Type' => 'application/json' },
               'httpMethod' => 'POST',
               'path' => '/token'
             })

  # Generate a token
  payload = {
    data: { user_id: 128 },
    exp: Time.now.to_i + 1,
    nbf: Time.now.to_i
  }
  token = JWT.encode payload, ENV['JWT_SECRET'], 'HS256'
  # Call /
  PP.pp main(context: {}, event: {
               'headers' => { 'Authorization' => "Bearer #{token}",
                              'Content-Type' => 'application/json' },
               'httpMethod' => 'GET',
               'path' => '/'
             })
end
