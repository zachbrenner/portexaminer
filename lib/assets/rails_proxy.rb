class RailsProxy < Rack::Proxy
  def rewrite_env(env)
    env['HTTP_HOST'] = 'portexaminer.com'
    env['SERVER_PORT'] = 80

    # Remove forwarding parameters
    env['SCRIPT_NAME'] = nil
    env['HTTP_X_FORWARDED_PORT'] = nil
    env['HTTP_X_FORWARDED_PROTO'] = nil

    # Do some other stuff as needed
    # ...

    # Return the 'env'
    env
  end
end
