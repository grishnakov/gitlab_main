helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600s \
  --set global.hosts.domain=agrishakov.com \
  --set global.hosts.externalIP=75.80.52.243\
  --set certmanager-issuer.email=grishalmax@gmail.com \
  --set global.edition=ce\
  
