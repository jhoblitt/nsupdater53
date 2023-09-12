# nsupdater53

## Usage

```bash
kinit
ipa dns-update-system-records --dry-run --out nsupdate.txt
./nsupdater53.rb nsupdate.txt XXXXXXXXXXXXXX > dns.tf
terraform apply
```
