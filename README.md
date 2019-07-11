# DNS over TLS and TOR with Pi-Hole


These instructions will set up your Pi-Hole to run DNS over TLS and TOR.  

For those unfamiliar, [here](https://dnsprivacy.org/wiki/display/DP/DNS+Privacy+-+The+Problem)  is a description of the issues with regular DNS.

DNS over TLS encrypts the DNS requests between you and the DNS provider so that only you and the DNS provider know what requests you have made.   The DNS provider however will have both your IP address and your request.

By adding TOR to the chain, no one has access to your request and your IP address.
The DNS provider will see a Tor exit node making the request and the Tor exit node will see an encrypted message going out to the DNS provider.

Its a small step to increasing your privacy online, but its fairly easy.

## To note:

Your ISP will still see all your regular traffic, this is a reduction in footprint, not a magic bullet.

DNS over TLS and TOR is slower.  The instructions below should increase your caching of DNS entries (a cached DNS entry is very fast)  but non-cached entries may take up to a second to resolve.

In practice, I havent noticed a slowdown.  Currently with pi-hole, 50% of my requests are cached, 20% are blocked and only 30% are resolved externally.


## The setup

This stack points the pi-hole DNS to use stubby (which performs DNS over TLS) which is then redirected via proxychains to TOR.  These instructions assume you have set up pi-hole.  
If not please install pi-hole [first](https://github.com/pi-hole/pi-hole/#one-step-automated-install) . 


## Instructions

**Playing around with DNS can result in you not being able to resolve any domain names and therefore no access to the internet and no way to google how to get out of the mess.
You should, at the minimum have the ip address of your pi-hole so that you can access it to turn off the new DNS server and a copy of these instructions locally.  If you are not confident you can recover from DNS issues, this probably isnt for you, or test it out on a test machine rather than your main DNS server**

Log into your pi-hole.

Check everything is up to date.

	sudo apt-get update && sudo apt-get upgrade

### Install TOR

	sudo apt-get install tor
	
	
Check tor installation.

	sudo netstat -tpln
	

*Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      504/sshd            
tcp        0      0 127.0.0.1:**9050**          0.0.0.0:*               LISTEN      3057/**tor**            
tcp6       0      0 :::22                   :::*                    LISTEN      504/sshd            
*

We are looking for tor listening on port 9050.

Check its working
Firstly my ip without tor.

	curl ifconfig.me

Then your ip with tor.

	torsocks curl ifconfig.me
	

These two should be different.

### Install stubby

Stubby is now in buster so if you have buster you can just

	sudo apt-get install stubby

This actually starts the program so we need to stop it.

	sudo systemctl stop stubby

If you dont have stubby in your repositories there is a description [here](https://www.reddit.com/r/pihole/comments/7oyh9m/guide_how_to_use_pihole_with_stubby/)  of how to build it from source.

(Note it might be worth building it from source anyway to get the latest version).

Change the port that stubby listens on.

	sudo nano /etc/stubby/stubby.yml

Change the listen_addresses to 

listen_addresses:
  - 127.0.0.1**@8053**
  - 0::1**@8053**

Save and exit.

Now start stubby

	sudo systemctl start stubby
	
And test it.

	dig @127.0.0.1 -p 8053 google.com

This should return an ip address for google.

Now lets stop stubby for the momment

	sudo systemctl stop stubby

### Install proxychains

	sudo apt-get install proxychains

We know need to make a change to the proxychains config to not do dns resolution.

	sudo nano /etc/proxychains.conf

Comment out the line

proxy_dns 

so that it appears like this.

\# proxy_dns 

and at the end of the file change socks4 to socks5 ie.

socks5  127.0.0.1 9050

(Not sure if this is really necessary).

Save and exit.

To check it is working 

	proxychains curl ifconfig.me

and 

	curl ifconfig.me
	
should give different ip addresses.

### Connecting them together

To test its all working type the following 

	proxychains stubby &

and test it.

	dig @127.0.0.1 -p 8053 google.com

You should get back the ip address.  In the returned records you should see the time the request took.
Its probably very slow but we can speed that up later.

Now stop our test server.

	killall stubby

### Setting it up for the system

	sudo nano /etc/systemd/system/multi-user.target.wants/stubby.service


and change the ExecStart line to be

**ExecStart=/usr/bin/proxychains /usr/bin/stubby**

and change the After line to be (adding tor.service)

**After=network-online.target tor.service**

Save it and exit.

Run the following

	sudo systemctl daemon-reload
	sudo systemctl start stubby

and test it.

	dig @127.0.0.1 -p 8053 google.com
	
### Adding it to Pi-hole.

Go to your pi-hole web interface and go to settings.
There is a tab at the top called DNS, go there.

Turn off your other DNS providers and add  Custom server

**127.0.0.1#8053**

Hit save at the bottom of the page and we should be done.

We can test it using

	dig apple.com
	
We should use an address we havent checked before because the pi-hole caches dns requests.
If everything is working, the dig command will probably be quite slow.

### Speeding up

Firstly add a minimum TTL (Time to live) to DNS requests.
This will be DNS requests should be repeated within about an hour.
IP addresses rarely move but  you may want a smaller value in certain cases.

Type the following.


	sudo bash
	
	cat << EOF > /etc/dnsmasq.d/min_tls.conf
	min-cache-ttl=3500
	EOF
	exit
	

Secondly change the servers that stubby uses.

	sudo nano /etc/stubby/stubby.yml

Uncomment (for google servers) the following

\## Google
  - address_data: 8.8.8.8
  
    tls_auth_name: "dns.google"
    
  - address_data: 8.8.4.4
  
    tls_auth_name: "dns.google"
    
Increase the idle_timeout (in milliseconds)

**idle_timeout: 1000000**

Save and exit.


Restart pi-hole and stubby

	sudo systemctl restart stubby
	sudo systemctl restart pihole-FTL
	

Test again.

	dig apple.com

which is probably not going to break any speed records, though it we try it again

	dig apple.com

We should get a response in a millisecond.

### To get back to old DNS servers.

If you want to remove this configuration, 
change the DNS server back on the pi-hole web interface to your preffered DNS server and remove the 127.0.0.1#8053 entry.
Save

Thtat should get your dns back to how it was.

To stop the stubby service from running.

	sudo systemctl disable stubby
	sudo systemctl stop stubby
	
