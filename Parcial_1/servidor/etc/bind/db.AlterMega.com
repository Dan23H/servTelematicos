;
; BIND data file for local loopback interface
;
$TTL	604800
@	IN	SOA	AlterMega.com. root.AlterMega.com (
			      4		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	ns.AlterMega.com.
ns	IN	A	192.168.50.3
maestro	IN	CNAME	ns
master	IN	CNAME 	ns
esclavo IN 	A	192.168.50.2
slave 	IN 	CNAME	esclavo
