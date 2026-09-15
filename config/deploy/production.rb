server "54.238.218.131",
       user: "ec2-user",
       roles: %w[app db web],
       ssh_options: {
         keys: [File.expand_path("~/Downloads/aws-deploy-task-key.pem")],
         forward_agent: false,
         auth_methods: %w[publickey]
       }

set :rails_env, "production"