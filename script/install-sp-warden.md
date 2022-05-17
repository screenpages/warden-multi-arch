# install SP-warden

## Add your SSH key to github
- Go to githut: https://github.com/settings/keys
- Select `New SSH key` button
- The title is for personal reference, call it something useful such as "SpWorkMachine2022"
- Copy your SSH key, run `pbcopy < ~/.ssh/id_rsa.pub` from your terminal
- Paste into the key field
- Press save

---
## Install
To Install SP Warden Version, run the following command from terminal

`curl -s https://raw.githubusercontent.com/screenpages/warden-multi-arch/debian/script/spInstall | bash`
