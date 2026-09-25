extends Node
## Data source for every scenario/day in the game. Add a new threat by appending one
## entry to SCENARIOS below -- the Scenario Book and progression system read from this
## list instead of hardcoding days, so no other script needs to change.

const SCENARIOS: Array[Dictionary] = [
	{
		"id": "credential_abuse",
		"day": 1,
		"threat_name": "Credential Abuse",
		"story": {
			"day_introduction": [
				{"speaker": "IT Director", "text": "We picked up something odd overnight -- a spike of failed logins on one of our accounts, then a login that finally went through. I need you to find out if that was really the account owner, or someone who shouldn't be in there.", "position": "right"},
				{"speaker": "Analyst", "text": "Understood. A burst of failed logins followed by a success is a classic sign of Credential Abuse -- someone guessing or reusing stolen credentials until one works. I'll start by pulling the login records and the logs.", "position": "left"},
			],
			"investigation_to_monitoring": [
				{"speaker": "Analyst", "text": "The evidence lines up: a login from a location and device this account has never used before, right after over a dozen failed attempts at an hour the employee wasn't even scheduled to work. That's Credential Abuse -- this account has been compromised.", "position": "left"},
				{"speaker": "Analyst", "text": "Knowing what already happened isn't the same as knowing what's happening right now. I need to watch live activity and catch it if the attacker is still active.", "position": "left"},
			],
			"monitoring_to_hardening": [
				{"speaker": "Analyst", "text": "Not every unusual login is an attack -- one of the other logins I watched checked out completely against the employee's real schedule and device. But the activity on the compromised account was real, and I reported it.", "position": "left"},
				{"speaker": "Analyst", "text": "Before I move to actively respond, I should spend what we've earned on stronger defenses. The choices I make now decide what tools I'll have when I face this threat directly.", "position": "left"},
			],
			"hardening_to_response": [
				{"speaker": "Analyst", "text": "Defenses are in place. Requiring a second verification step and tightening account controls gives me real tools to use, not just a hope that this stops on its own.", "position": "left"},
				{"speaker": "Analyst", "text": "Time to actively respond. I'll use what I've prepared to shut this account down before it causes any more damage.", "position": "left"},
			],
			"response_to_recovery": [
				{"speaker": "Analyst", "text": "The compromised account is locked down and the attacker's access is cut off. But containing an attack doesn't undo the damage it already caused.", "position": "left"},
				{"speaker": "Analyst", "text": "Some systems took damage while the attacker had access. I need to go through and repair what was affected before we can call this incident closed.", "position": "left"},
			],
			"day_conclusion": [
				{"speaker": "Analyst", "text": "Every affected system is back online. The account is secured, and the incident is fully resolved.", "position": "left"},
				{"speaker": "IT Director", "text": "Good work. A second verification step should have caught this sooner -- let's make sure MFA stays on for every account, not just the ones that end up compromised.", "position": "right"},
				{"speaker": "Analyst", "text": "Agreed. I'll stay alert -- this won't be the last unusual activity we see.", "position": "left"},
			],
		},
		"tutorials": {
			"investigation": [
				{"speaker": "Analyst", "text": "This looks like it could be Credential Abuse. Let's dig through the account's activity -- logs, login records, and reports -- until the evidence is clear enough to be sure.", "position": "left"},
			],
			"monitoring": [
				{"speaker": "Analyst", "text": "Now I need to watch activity as it happens, not just look back at what already happened. I'll switch between views and report anything that looks like it's part of an ongoing attack.", "position": "left"},
			],
			"hardening": [
				{"speaker": "Analyst", "text": "Before I respond, I should spend our security resources wisely -- the right defenses now decide what I'll have available when I face this threat directly.", "position": "left"},
			],
			"response": [
				{"speaker": "Analyst", "text": "This is where I actively fight back. I'll play through the defenses I've prepared to contain the threat before it does more damage.", "position": "left"},
			],
			"recovery": [
				{"speaker": "Analyst", "text": "The threat is contained, but some systems were damaged along the way. I'll go through and repair each one until everything is back to normal.", "position": "left"},
			],
		},
		"investigation": {
			"required_evidence_count": 4,
			"applications": {
				"email": [
					{"id": "email_newsletter", "title": "IT Newsletter — Monthly Security Tips", "detail": "A routine monthly email with generic password-hygiene reminders. Nothing unusual.", "is_evidence": false},
					{"id": "email_meeting", "title": "Meeting Reminder — Standup at 10 AM", "detail": "An automated calendar reminder for the daily team standup.", "is_evidence": false},
				],
				"logs": [
					{"id": "repeated_auth_attempts", "title": "17 failed login attempts — Anna's account", "detail": "Between 02:30 and 02:43, there were 17 failed authentication attempts on Anna's account before a successful login.", "is_evidence": true},
					{"id": "log_backup", "title": "Routine backup completed", "detail": "Nightly backup job completed successfully at 01:00 with no errors.", "is_evidence": false},
				],
				"computers": [
					{"id": "computer_ws14", "title": "Workstation-14 — status normal", "detail": "Last check-in 2 hours ago. No anomalies reported.", "is_evidence": false},
					{"id": "computer_ws22", "title": "Workstation-22 — update pending", "detail": "A routine software update is pending installation.", "is_evidence": false},
				],
				"login_activity": [
					{"id": "strange_login_location", "title": "Anna — login from Germany at 02:43", "detail": "Anna's account logged in from an IP address in Germany. Anna has never logged in from outside the country before.", "is_evidence": true},
					{"id": "unknown_device", "title": "Anna — unrecognized device fingerprint", "detail": "The 02:43 login used a device fingerprint never before seen on Anna's account.", "is_evidence": true},
					{"id": "login_mark_night_shift", "title": "Mark — login from Philippines at 02:50", "detail": "Mark is a scheduled night-shift employee working remotely this week. This login matches his known device and shift.", "is_evidence": false},
				],
				"files": [
					{"id": "files_budget", "title": "Shared Drive — Q3 Budget.xlsx modified", "detail": "Mark updated the shared budget spreadsheet earlier today, consistent with his normal duties.", "is_evidence": false},
				],
				"network": [
					{"id": "network_firewall", "title": "Firewall — no blocked connections", "detail": "No blocked or flagged connections in the last 24 hours.", "is_evidence": false},
				],
				"servers": [
					{"id": "server_db01", "title": "Server-DB01 — uptime 42 days", "detail": "No errors logged. Uptime and load are within normal range.", "is_evidence": false},
				],
				"reports": [
					{"id": "unusual_time_activity", "title": "Anna's shift schedule", "detail": "According to HR records, Anna was not scheduled to work at 02:43. Her regular hours are 9 AM to 5 PM.", "is_evidence": true},
					{"id": "report_weekly_summary", "title": "Weekly performance summary", "detail": "All teams on track this week. No flagged incidents in this report.", "is_evidence": false},
				],
			},
		},
		"monitoring": {
			"duration_seconds": 45,
			"events": [
				{
					"id": "login_anna_germany",
					"view": "login",
					"summary": "02:43 — Anna — Germany — Unknown Device",
					"title": "SUSPICIOUS LOGIN DETECTED",
					"details": [
						{"label": "Account", "value": "Anna"},
						{"label": "Location", "value": "Germany"},
						{"label": "Device", "value": "Unknown Device"},
						{"label": "Time", "value": "02:43"},
					],
					"should_report": true,
					"important": true,
				},
				{
					"id": "login_repeated_failed",
					"view": "login",
					"summary": "02:30-02:43 — 17 failed logins then success — Anna",
					"title": "REPEATED AUTHENTICATION ATTEMPTS",
					"details": [
						{"label": "Account", "value": "Anna"},
						{"label": "Failed Attempts", "value": "17"},
						{"label": "Outcome", "value": "Eventually succeeded"},
						{"label": "Time", "value": "02:30 - 02:43"},
					],
					"should_report": true,
					"important": false,
				},
				{
					"id": "login_mark_night_shift",
					"view": "login",
					"summary": "02:50 — Mark — Philippines — Company Laptop",
					"title": "LOGIN ACTIVITY",
					"details": [
						{"label": "Account", "value": "Mark"},
						{"label": "Location", "value": "Philippines"},
						{"label": "Device", "value": "Company Laptop"},
						{"label": "Time", "value": "02:50"},
						{"label": "Note", "value": "Mark is a scheduled night-shift employee working remotely this week."},
					],
					"should_report": false,
					"important": false,
				},
				{
					"id": "computer_anna_unusual_app",
					"view": "computer",
					"summary": "Anna's workstation — unrecognized application launched",
					"title": "UNUSUAL PROCESS ACTIVITY",
					"details": [
						{"label": "Workstation", "value": "Anna-WS07"},
						{"label": "Activity", "value": "Unrecognized remote-access tool launched"},
						{"label": "Time", "value": "02:44"},
					],
					"should_report": true,
					"important": false,
				},
				{
					"id": "computer_ws14_normal",
					"view": "computer",
					"summary": "Workstation-14 — routine check-in",
					"title": "COMPUTER STATUS",
					"details": [
						{"label": "Workstation", "value": "Workstation-14"},
						{"label": "Activity", "value": "Routine check-in, no anomalies"},
						{"label": "Time", "value": "03:00"},
					],
					"should_report": false,
					"important": false,
				},
				{
					"id": "network_outbound_unknown",
					"view": "network",
					"summary": "Anna's workstation — outbound connection to unrecognized IP",
					"title": "SUSPICIOUS NETWORK ACTIVITY",
					"details": [
						{"label": "Source", "value": "Anna-WS07"},
						{"label": "Destination", "value": "Unrecognized external IP"},
						{"label": "Time", "value": "02:45"},
					],
					"should_report": true,
					"important": true,
				},
				{
					"id": "network_firewall_normal",
					"view": "network",
					"summary": "Firewall — no blocked connections",
					"title": "NETWORK STATUS",
					"details": [
						{"label": "Status", "value": "No blocked or flagged connections"},
						{"label": "Time", "value": "03:05"},
					],
					"should_report": false,
					"important": false,
				},
				{
					"id": "server_db01_normal",
					"view": "server",
					"summary": "Server-DB01 — nominal load",
					"title": "SERVER STATUS",
					"details": [
						{"label": "Server", "value": "Server-DB01"},
						{"label": "Load", "value": "Nominal"},
						{"label": "Time", "value": "03:10"},
					],
					"should_report": false,
					"important": false,
				},
			],
		},
		"hardening": {
			"base_deck": ["Investigate", "Scan", "Block", "Isolate"],
			"shop_items": [
				{
					"id": "mfa",
					"name": "MFA",
					"category": "defense",
					"cost": 30,
					"description": "Require a second verification step before granting account access.",
					"unlocks_card": "Force Re-authentication",
				},
				{
					"id": "account_protection",
					"name": "Account Protection",
					"category": "defense",
					"cost": 25,
					"description": "Lock down a compromised account to stop further unauthorized use.",
					"unlocks_card": "Disable Account",
				},
				{
					"id": "improved_logging",
					"name": "Improved Logging",
					"category": "support",
					"cost": 20,
					"description": "Capture more detail from system activity, making it easier to trace an attacker's actions.",
					"unlocks_card": "Trace Activity",
				},
				{
					"id": "network_segmentation",
					"name": "Network Segmentation",
					"category": "defense",
					"cost": 50,
					"description": "Isolate network segments from each other to contain lateral movement.",
					"unlocks_card": "Isolate Network",
				},
				{
					"id": "increased_integrity",
					"name": "Increased System Integrity",
					"category": "passive",
					"cost": 15,
					"description": "Permanently increases starting System Integrity for the Response phase.",
					"passive_effect": "Increased System Integrity",
				},
			],
		},
		"response": {
			"card_pool": {
				"Investigate": {"energy": 1, "type": "Response", "logic": "Gain 10 Containment", "tooltip": "A basic diagnostic action against the active threat."},
				"Scan": {"energy": 1, "type": "Response", "logic": "Gain 8 Containment", "tooltip": "Scan for further signs of compromise."},
				"Block": {"energy": 1, "type": "Recovery", "logic": "Restore 8 Integrity", "tooltip": "Block a minor intrusion attempt."},
				"Isolate": {"energy": 1, "type": "Recovery", "logic": "Restore 10 Integrity", "tooltip": "Briefly isolate an affected system."},
				"Force Re-authentication": {"energy": 2, "type": "Response", "logic": "Gain 20 Containment", "tooltip": "Require the account to re-verify its identity."},
				"Disable Account": {"energy": 2, "type": "Response", "logic": "Gain 18 Containment", "tooltip": "Lock the compromised account entirely."},
				"Trace Activity": {"energy": 1, "type": "Response", "logic": "Gain 12 Containment", "tooltip": "Trace the attacker's recent actions."},
				"Isolate Network": {"energy": 3, "type": "Response", "logic": "Gain 25 Containment", "tooltip": "Cut off the network segments the attacker is using."},
			},
			"boss": {
				"id": "credential_abuse",
				"name": "Credential Abuse",
				"max_hp": 100,
				"intents": [
					{
						"id": "unauthorized_login",
						"label": "ATTEMPTING ACCESS",
						"description": "The attacker is trying to use a compromised account to log in.",
						"damage": 12,
						"component": "Server",
					},
					{
						"id": "credential_replay",
						"label": "REPLAYING CREDENTIALS",
						"description": "The attacker is reusing the stolen login details against other systems.",
						"damage": 15,
						"component": "Database",
					},
					{
						"id": "session_hijack",
						"label": "HIJACKING A SESSION",
						"description": "The attacker is trying to take over a session that's already logged in.",
						"damage": 10,
						"component": "Router",
					},
					{
						"id": "privilege_escalation",
						"label": "ESCALATING ACCESS",
						"description": "The attacker is trying to gain more access than the compromised account should have -- and getting bolder the longer this goes unchecked.",
						"damage": 14,
						"component": "Switch",
						"damage_growth": 4,
					},
				],
				"reactive_intent_id": "privilege_escalation",
				"reactive_threshold_percent": 50,
			},
		},
		"recovery": {
			"minigame_types": {
				"Server": {"type": "pattern_matching", "label": "Pattern Repair"},
				"Router": {"type": "connection_path", "label": "Connection Repair"},
				"Switch": {"type": "connection_path", "label": "Connection Repair"},
				"Computer": {"type": "timing_rhythm", "label": "Timing Repair"},
				"Database": {"type": "sequence_puzzle", "label": "Sequence Repair"},
			},
		},
	},
	{"id": "malware", "day": 2, "threat_name": "Malware"},
	{"id": "ransomware", "day": 3, "threat_name": "Ransomware"},
	{"id": "insider_threat", "day": 4, "threat_name": "Insider Threat"},
	{"id": "data_exfiltration", "day": 5, "threat_name": "Data Exfiltration"},
	{"id": "ddos", "day": 6, "threat_name": "Distributed Denial-of-Service (DDoS)"},
	{"id": "phishing", "day": 7, "threat_name": "Phishing"},
	{"id": "web_application_attack", "day": 8, "threat_name": "Web Application Attack"},
]


func get_scenario_for_day(day: int) -> Dictionary:
	for scenario in SCENARIOS:
		if scenario.get("day") == day:
			return scenario
	return {}


func get_scenario_by_id(id: String) -> Dictionary:
	for scenario in SCENARIOS:
		if scenario.get("id") == id:
			return scenario
	return {}


func get_day_count() -> int:
	return SCENARIOS.size()
