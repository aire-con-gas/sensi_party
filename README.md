# SensiParty
SensiParty - wrapper to interact with the [Emerson Sensi thermostat](http://www.emersonclimate.com/en-us/products/thermostats/sensi/pages/sensi-wifi-thermostat.aspx). Special thanks to @mguterl and the [mguterl/sensi](https://github.com/mguterl/sensi) library. This is still a work in progress

# Known Issue
- setHeat in sensi.rb is not working. Getting a 500 error with this

# Usage
```ruby
s = SensiParty::Sensi.new
s.start
s.getThermostats
s.setHeat(70)
```
