require 'tentd'

TentValidator.tentd
class TentServer
  def call(env)
    match = env['PATH_INFO'] =~ %r{\A/([^/]+)/tent(.*)}
    if match && (user = TentD::Model::User.first(:public_id => $1))
      TentD::Model::User.current = user
      env['tent.entity'] = user.entity
      env['PATH_INFO'] = $2
      TentValidator.tentd.call(env)
    else
      [404, { 'Content-Type' => 'text/plain' }, ['Not Found']]
    end
  end
end
