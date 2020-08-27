curl --output EduVPN-redesign/Resources/Discovery/server_list.json https://disco.eduvpn.org/v2/server_list.json
curl --output server_list.json.minisig https://disco.eduvpn.org/v2/server_list.json.minisig

curl --output EduVPN-redesign/Resources/Discovery/organization_list.json https://disco.eduvpn.org/v2/organization_list.json
curl --output organization_list.json.minisig https://disco.eduvpn.org/v2/organization_list.json.minisig

minisign -V -x ./server_list.json.minisig -P RWRtBSX1alxyGX+Xn3LuZnWUT0w//B6EmTJvgaAxBMYzlQeI+jdrO6KF -m EduVPN-redesign/Resources/Discovery/server_list.json
minisign -V -x ./organization_list.json.minisig -P RWRtBSX1alxyGX+Xn3LuZnWUT0w//B6EmTJvgaAxBMYzlQeI+jdrO6KF -m EduVPN-redesign/Resources/Discovery/organization_list.json

