# -*- coding: utf-8 -*-
"""The text of the seed PDFs (library documents and chapter whitepapers).

Used by make_seed_files.py. Plain data: a document is a title, a subtitle, the library "kind" it
belongs to and a list of blocks:  ('h', heading)  ('p', [paragraphs])  ('b', [bullets])
('n', [numbered steps])  ('t', head_row, rows, col_widths_or_None).
Text stays inside Windows-1252 (the PDFs use the built-in Helvetica): "Rs" for the rupee sign,
"->" for arrows, ">=" for greater-or-equal.
"""


def H(t):
    return ('h', t)


def P(*ps):
    return ('p', list(ps))


def B(*items):
    return ('b', list(items))


def N(*items):
    return ('n', list(items))


def T(head, rows, widths=None):
    return ('t', head, rows, widths)


PDFS = {}

PDFS['fm-handover-checklist'] = dict(
    title='FM Handover Checklist: New Building Takeover',
    subtitle='A 60-point checklist for taking a new or refurbished building from the project team into operations',
    kind='Checklists',
    blocks=[
        P('A handover is the moment the project team stops owning the building and the operations team starts. Most of the '
          'cost of a bad handover is paid in year one: undocumented plant, missing warranties, alarms nobody has tested and '
          'a maintenance contract priced against a building that does not match the drawings. This checklist is the one '
          'Chapter members use to refuse a handover until the evidence is in the room.'),
        H('1. Documents the operations team must hold on day one'),
        B('As-built drawings (architectural, structural, MEP, fire, BMS) in editable and PDF form, signed by the contractor',
          'Operation and maintenance manuals for every item of plant, indexed by asset tag',
          'Warranty register with start dates, durations, exclusions and the contractor contact for each item',
          'Statutory approvals: fire NOC, occupancy certificate, lift licences, DG and boiler certificates, pollution consent',
          'Test and commissioning certificates with the witnessed readings, not just the cover sheet',
          'Spares and special tools schedule, with quantities received',
          'Training attendance sheets for each system (security, BMS, HVAC, fire, lifts, DG)'),
        H('2. Physical walk-down'),
        N('Walk every floor with the main contractor and note defects on a snag list with photographs and a location code.',
          'Test every fire alarm device, sprinkler flow switch and emergency light; record the panel response time.',
          'Run each lift through full-load, fireman and power-failure modes with the lift contractor present.',
          'Check every plant room for access, lighting, drainage, labelling and a clear maintenance envelope.',
          'Confirm every meter, sub-meter and BMS point reads sensibly against a handheld instrument.',
          'Inspect roof, terraces, basement and service shafts for water ingress, ponding and unprotected openings.'),
        H('3. Systems and data'),
        T(['System', 'Evidence required', 'Owner', 'Accepted'],
          [['Fire detection and alarm', 'Zone chart, cause-and-effect test, panel log', 'Fire engineer', '[ ]'],
           ['Sprinkler and hydrants', 'Hydraulic test, pump curve, flow test', 'MEP lead', '[ ]'],
           ['HVAC and chilled water', 'Balancing report, setpoint schedule, trend logs', 'MEP lead', '[ ]'],
           ['Electrical and DG', 'Thermography, earth-pit readings, DG load test', 'Electrical lead', '[ ]'],
           ['BMS and metering', 'Point list, graphics, alarm limits, trend export', 'BMS engineer', '[ ]'],
           ['Lifts and escalators', 'Licence, load test, emergency phone test', 'Lift contractor', '[ ]']],
          [110, 190, 80, 50]),
        H('4. Contracts and people'),
        B('Every service contract mapped to the assets and areas it covers; no gaps and no double cover',
          'Response and resolution times agreed, with an escalation matrix that names a person for every level',
          'Helpdesk, CMMS and permit-to-work configured before the first tenant or employee arrives',
          'A named defects-liability owner who chases the contractor until the last snag is closed',
          'Emergency contact tree printed, tested by phone and held at the security desk'),
        H('5. Sign-off rules'),
        P('Do not sign a handover certificate with open category-A items (anything that affects life safety, statutory '
          'compliance or the ability to occupy). Category-B items go on the defects register with a dated owner. Keep the '
          'retention money until the warranty register, the as-built set and the training records are complete.'),
    ])

PDFS['fire-life-safety-sop'] = dict(
    title='Fire & Life Safety SOP: Alarm Response and Evacuation',
    subtitle='Standard operating procedure for corporate campuses and multi-tenant towers',
    kind='SOPs',
    blocks=[
        P('Purpose: to make sure every person on site knows what to do in the first ten minutes of a fire alarm, and that '
          'the control room, wardens and security act in the same order every time. Scope: all occupied buildings, basements '
          'and car parks. Owner: Head of Facilities. Review: every six months and after every drill or incident.'),
        H('1. Roles'),
        T(['Role', 'Primary duty', 'Back-up'],
          [['Fire control room operator', 'Verify the alarm, call the fire service, run the announcement script', 'Security supervisor'],
           ['Floor warden', 'Sweep the floor, close doors, direct people to stairs, report headcount', 'Deputy warden'],
           ['Security supervisor', 'Open emergency exits, hold lifts at ground, meet the fire service at the gate', 'Site manager'],
           ['Engineer on shift', 'Confirm panel status, isolate affected AHUs, check pump health', 'Duty engineer'],
           ['Site manager', 'Incident commander until the fire service takes over', 'Head of Facilities']],
          [120, 250, 100]),
        H('2. Alarm response (first ten minutes)'),
        N('Alarm sounds: the control room operator identifies the zone and device on the panel and silences nothing until the floor is verified.',
          'Within 60 seconds a warden or security guard visits the zone. A confirmed fire, smoke or burning smell triggers evacuation.',
          'The operator calls the fire service on 101 and the site manager, and starts the staged evacuation announcement.',
          'Wardens sweep their floor, check toilets, meeting rooms and phone booths, then use the stairs. Lifts are not used.',
          'Engineers shut down the AHUs serving the affected zone, start the pressurisation fans and confirm the pumps are on auto.',
          'At the assembly point wardens report headcount to the site manager using the visitor and attendance lists.',
          'The site manager hands over to the fire officer, shares the floor plans and the hazard list, and keeps the gate clear.'),
        H('3. Evacuation announcement script'),
        P('"May I have your attention please. A fire alarm has been activated in the building. Please leave by the nearest '
          'staircase and walk to the assembly point. Do not use the lifts. Do not stop to collect belongings. Wardens will '
          'guide you." Repeat every 30 seconds in English and the local language until the all-clear.'),
        H('4. People who need help'),
        B('Maintain a confidential register of people who cannot use stairs unaided; wardens know their floor locations',
          'Use refuge areas and evacuation chairs; tell the fire service where each person waits',
          'Visitors are the host\'s responsibility until the host reports them at the assembly point'),
        H('5. After the incident'),
        B('Do not re-enter until the fire officer permits it; reset the panel only with the fire engineer present',
          'Log the event within 24 hours: time of alarm, cause, response times, injuries, damage and lessons',
          'Run a debrief within five working days and update this SOP where the response fell short',
          'Test every evacuated device and replace anything operated or damaged before the building is declared safe'),
        H('6. Drills'),
        P('Run an unannounced evacuation drill at least twice a year per building, one in office hours and one at shift '
          'change. Record the time to clear each floor; the target is under four minutes per ten floors. Wardens who miss '
          'a drill are re-trained within a month.'),
    ])

PDFS['vendor-sla-management-guide'] = dict(
    title='Vendor SLA Management: A Practical Guide',
    subtitle='How to write service levels that can be measured, reviewed and enforced',
    kind='Best Practices',
    blocks=[
        P('A service level agreement is only as good as the report that proves it. Most disputes between a facilities team '
          'and an integrated services provider are not about effort; they are about how a response time was measured, '
          'whether a task was complete and who owns the root cause. This guide sets out the practices Chapter members '
          'have found to work in India\'s office and campus portfolios.'),
        H('1. Start from outcomes the business notices'),
        B('Comfort: temperature and humidity inside the agreed band for at least 95% of occupied hours',
          'Availability: critical plant (chillers, DG, UPS, lifts) available at least 99.5% of the time',
          'Responsiveness: priority-one complaints acknowledged in 10 minutes and resolved in 2 hours',
          'Cleanliness: audited score of 90 or better on the monthly inspection, by area type',
          'Safety: zero lost-time incidents and 100% closure of statutory compliance actions on due date'),
        H('2. Define each measure completely'),
        T(['Element', 'Example: priority-one response'],
          [['Definition', 'Time from ticket creation to engineer on site with the task acknowledged'],
           ['Clock', 'Helpdesk timestamp, 24x7, stopped only by a client-approved pause reason'],
           ['Target / floor', '10 minutes / 20 minutes'],
           ['Data source', 'CMMS export, reconciled monthly with the client helpdesk'],
           ['Remedy', 'Service credit of 1% of the monthly fee per 5 percentage points below target'],
           ['Owner', 'Provider account manager; client contract manager reviews']],
          [100, 370]),
        H('3. Governance cadence'),
        N('Daily: shift handover and open-priority review at the site level.',
          'Weekly: contract manager and provider supervisor review aged tickets and repeat failures.',
          'Monthly: SLA scorecard, credits, audits and a short list of improvement actions with owners.',
          'Quarterly: business review with finance, HR and the provider\'s regional head; reset targets and approve changes.'),
        H('4. Credits and bonuses'),
        P('Keep credits proportionate and capped (typically 10 to 15% of the monthly fee) so the provider stays solvent and '
          'engaged. Pair credits with a smaller bonus for sustained out-performance and for cost-saving ideas that the client '
          'validates. Never let credits be waived informally; record each waiver and its reason in the scorecard.'),
        H('5. Common failure points'),
        B('Targets copied from another site without checking the plant, occupancy or hours',
          'Penalties so high that the provider stops reporting honestly',
          'No baseline period; the first three months should be measurement-only',
          'Changes to scope agreed on email but never written into the contract schedule'),
    ])

PDFS['brsr-core-esg-reporting-guide'] = dict(
    title='BRSR Core for Facilities Teams',
    subtitle='The nine attributes, what data facilities must supply and how to keep it audit-ready',
    kind='Standards',
    blocks=[
        P('SEBI\'s Business Responsibility and Sustainability Report (BRSR) Core asks listed companies to disclose a '
          'limited set of key performance indicators with reasonable assurance. Several of them, energy, water, waste, '
          'emissions and safety, are produced by the facilities function. This summary explains what the facilities team '
          'is expected to hand over and how to make the numbers survive an assurance review.'),
        H('1. Attributes with a facilities footprint'),
        T(['Attribute', 'Facilities data', 'Typical source'],
          [['Greenhouse gas footprint', 'Scope 1 fuel (DG, boilers, refrigerant top-ups); Scope 2 purchased electricity', 'Meters, DG logs, refrigerant register'],
           ['Water footprint', 'Withdrawal, consumption, discharge and recycled water by source', 'Water meters, STP logs'],
           ['Energy footprint', 'Total energy, share from renewable sources, intensity per sq ft', 'Utility bills, sub-meters, PPA statements'],
           ['Circularity', 'Waste generated, recycled, reused and disposed by category', 'Waste manifests, vendor weigh slips'],
           ['Employee and worker wellbeing', 'Safety incidents, LTIFR, fatalities, safety training', 'Incident register, HSE reports'],
           ['Fairness in the value chain', 'Share of spend with MSME and local suppliers', 'Vendor master and PO data']],
          [110, 220, 140]),
        H('2. Making data assurance-ready'),
        N('Fix the boundary: list the buildings, floors and tenants in scope and keep it identical across the year.',
          'Reconcile meter reads to utility bills monthly and document every estimate with its method.',
          'Keep one evidence folder per metric: raw data, calculation sheet, emission factors with source and year, sign-off.',
          'Use the same emission factors as the corporate sustainability team (CEA grid factor, IPCC for fuels).',
          'Lock the month after the review so figures cannot change silently; log every restatement.'),
        H('3. Quick wins that improve the numbers'),
        B('Sub-meter chillers, lighting and data rooms to find the largest controllable loads',
          'Separate tenant consumption so landlord energy is not overstated',
          'Switch DG hours to a log with start, stop and load, not a monthly estimate',
          'Move water-intensive cooling-tower make-up to treated STP water where the process allows'),
        H('4. Questions assurers ask'),
        B('How do you know the meter is accurate and when was it last calibrated?',
          'What is excluded from the boundary and why?',
          'How did you treat a month with a missing bill?',
          'Who approved the final numbers and where is the evidence?'),
    ])

PDFS['mep-commissioning-standard'] = dict(
    title='MEP Commissioning Standard (Summary)',
    subtitle='Stages, witness points and acceptance criteria for mechanical, electrical and plumbing systems',
    kind='Standards',
    blocks=[
        P('Commissioning proves that a building performs as designed before the owner accepts it. This summary condenses '
          'the practice recommended by the Construction & MEP Council into six stages and a set of witness points that the '
          'owner\'s representative should attend.'),
        H('1. Stages'),
        N('Design review: confirm the owner\'s project requirements are traceable to the drawings and the control sequences.',
          'Submittals and factory tests: witness the chiller, transformer, DG and fire pump tests at the factory where possible.',
          'Installation checks: pre-functional checklists for every item, signed by the installer before power is applied.',
          'Start-up: manufacturer start-up with the commissioning agent, recording baseline readings.',
          'Functional performance tests: run each system through its sequences, failure modes and load steps.',
          'Integrated systems test: power failure, fire alarm interface, lift recall, smoke control and BMS response together.'),
        H('2. Acceptance criteria'),
        T(['System', 'Test', 'Pass criterion'],
          [['Chilled water', '8-hour load test at design flow', 'Supply temp within 0.5 deg C of setpoint; delta-T >= 5.5 deg C'],
           ['Air side', 'Air balancing at all terminals', 'Within +/-10% of design airflow'],
           ['Electrical', 'Thermography at full load, protection relay tests', 'No hot spot over 15 deg C above ambient'],
           ['DG and ATS', 'Black-start with building load, 4-hour run', 'Transfer under 10 seconds; stable frequency'],
           ['Fire pumps', 'Flow test at 100% and 150% duty', 'Pressure and flow per the pump curve'],
           ['BMS', 'Point-to-point check, alarm simulation', '100% of points verified; alarms reach operators']],
          [90, 190, 190]),
        H('3. Documentation'),
        B('A commissioning plan agreed before the first installation check',
          'Issues log with severity, owner, closure date and re-test evidence',
          'Final commissioning report with trend data, test sheets and outstanding items',
          'Seasonal re-tests scheduled for the first summer and the first monsoon'),
    ])

PDFS['gcc-workplace-benchmark-2026'] = dict(
    title='GCC Workplace Benchmark 2026',
    subtitle='Space, cost, service and experience metrics from 38 Global Capability Centres in India',
    kind='Research',
    blocks=[
        P('This benchmark summarises the responses of 38 Global Capability Centres (GCCs) in Bengaluru, Hyderabad, Pune, '
          'Chennai and the NCR, covering about 62,000 seats. Figures are medians unless stated; ranges show the inter-quartile '
          'spread. Participation was anonymous and data was validated against each centre\'s lease and service contracts.'),
        H('1. Headline numbers'),
        T(['Metric', 'Median', 'Inter-quartile range'],
          [['Area per seat (sq ft)', '78', '65 to 92'],
           ['Peak weekday occupancy', '58%', '46% to 71%'],
           ['Seat-to-headcount ratio', '0.72', '0.60 to 0.85'],
           ['Integrated FM cost per sq ft per month (Rs)', '34', '27 to 43'],
           ['Cost per occupied seat per month (Rs)', '4,380', '3,500 to 5,600'],
           ['Cafeteria subsidy per meal (Rs)', '46', '30 to 62'],
           ['Helpdesk first-time-fix rate', '81%', '74% to 88%']],
          [230, 80, 160]),
        H('2. What high performers do differently'),
        B('Measure occupancy by badge, Wi-Fi and desk sensors together and plan against the 80th percentile day, not the average',
          'Run a single helpdesk with one SLA scorecard across hard and soft services',
          'Use a rolling 12-month service calendar so planned maintenance avoids peak anchor days',
          'Keep a small, empowered experience team instead of outsourcing every employee-facing decision',
          'Report cost per occupied seat, not only cost per square foot'),
        H('3. Space strategy'),
        P('Activity-based layouts now account for 62% of new fit-outs. Centres that moved to a 0.7 seat ratio saved a median '
          'of 9% on rent and 6% on operating cost but invested an average of Rs 1,800 per seat in booking tools, lockers and '
          'collaboration upgrades. The payback was 19 months. The most common regret was under-investing in meeting rooms: '
          'booking conflicts were the top experience complaint in 71% of centres.'),
        H('4. Experience and wellbeing'),
        B('Average monthly employee satisfaction with the workplace: 3.9 out of 5',
          'Top complaints: meeting-room availability, noise, temperature, parking, lift waiting times',
          'Centres with a daily air-quality display recorded 11% fewer comfort tickets',
          'Quiet zones and phone booths were rated more valuable than new breakout furniture'),
        H('5. Method note'),
        P('Seat counts were verified from layouts; costs include rent-free operating costs only; totals exclude capex and '
          'amortised fit-out. The sample is skewed towards centres of 800 to 5,000 seats. Treat the ranges as a guide for '
          'planning conversations, not as a target.'),
    ])

PDFS['lease-audit-playbook'] = dict(
    title='Lease Audit Playbook',
    subtitle='A step-by-step method for finding overcharges and missed rights in commercial leases',
    kind='Best Practices',
    blocks=[
        P('Lease audits routinely recover between 1% and 3% of annual occupancy cost, mostly from common-area maintenance '
          '(CAM), escalation and measurement errors. The method below is the one used in the Advanced Lease Audit Workshop '
          'and is designed to be repeated every year without outside help.'),
        H('1. Build the lease abstract'),
        B('Parties, premises, carpet and super area as defined, and the loading factor method',
          'Term, lock-in, renewal option and notice dates (put them in a calendar the day you finish)',
          'Rent, escalation formula, security deposit, interest on deposit and any rent-free period',
          'CAM, power, parking and other charges: basis, caps, audit rights and payment dates',
          'Repair, restoration and reinstatement obligations at exit'),
        H('2. Check the areas'),
        N('Obtain the occupancy certificate and the approved plan; confirm the carpet area against a laser survey.',
          'Recompute the loading factor with the landlord\'s stated common areas; compare with RERA norms for new leases.',
          'Reconcile billed area to measured area floor by floor, including the parking slots billed.'),
        H('3. Audit the charges'),
        T(['Charge', 'What to test', 'Typical finding'],
          [['Rent and escalation', 'Formula applied each anniversary; rounding', 'Escalation compounded instead of simple'],
           ['CAM', 'Landlord-level cost pool, allocation key, markup', 'Landlord costs and capex included'],
           ['Power', 'Sub-meter reads vs billed units, tariff slab, DG recovery', 'Commercial tariff billed on industrial load'],
           ['Property tax and insurance', 'Pass-through only if the lease allows', 'Tax of other tenants shared'],
           ['Parking', 'Count in lease vs billed', 'Visitor bays billed to tenant']],
          [100, 200, 170]),
        H('4. Present and recover'),
        P('Group findings by recoverability: clear errors (credit note requested), contested items (written query with '
          'lease references) and policy points for the next negotiation. Always send the landlord a calm, referenced '
          'note; most corrections are agreed in one meeting if the evidence is complete.'),
    ])

PDFS['hvac-ppm-policy'] = dict(
    title='HVAC Preventive Maintenance Policy',
    subtitle='Minimum standards for planned maintenance of chillers, AHUs, cooling towers and controls',
    kind='Policies',
    blocks=[
        P('Policy statement: all HVAC plant at ICR member sites shall be maintained to a written preventive maintenance (PPM) '
          'schedule that follows the manufacturer\'s instructions, statutory requirements and the risk rating of the asset. '
          'Work shall be recorded in the CMMS and reviewed monthly.'),
        H('1. Scope and responsibilities'),
        B('Applies to chillers, heat pumps, VRF and DX units, AHUs, FCUs, pumps, cooling towers, controls and ductwork',
          'The Facilities Manager owns this policy; the maintenance contractor delivers the schedule',
          'The Engineer in Charge approves deferrals; any deferral beyond 14 days is escalated to the Head of Facilities'),
        H('2. Minimum frequencies'),
        T(['Asset', 'Task', 'Frequency'],
          [['Chiller (water cooled)', 'Log readings, check oil, approach and condenser tube condition', 'Daily / quarterly'],
           ['Chiller', 'Eddy-current tube test, refrigerant and oil analysis', 'Annually'],
           ['AHU', 'Filter inspection, belt tension, coil cleaning', 'Monthly / quarterly'],
           ['Cooling tower', 'Basin clean, fill inspection, water treatment dosing check', 'Monthly'],
           ['Pumps', 'Vibration, seal and alignment check', 'Quarterly'],
           ['Controls', 'Sensor calibration, valve stroke, setpoint audit', 'Six-monthly']],
          [120, 250, 100]),
        H('3. Water quality and Legionella'),
        P('Cooling tower water shall be treated and tested monthly for total bacterial count, conductivity and Legionella '
          'risk indicators. Results outside limits trigger shock dosing, a retest within 48 hours and a notification to the '
          'Head of Facilities.'),
        H('4. Records and reporting'),
        B('Every task has a work order with start, finish, technician, parts and readings',
          'Planned compliance is reported monthly; the target is 95% on-time completion',
          'Repeat failures (the same fault twice in 90 days) require a documented root cause'),
        H('5. Review'),
        P('This policy is reviewed annually and after any plant failure that affects occupancy for more than four hours.'),
    ])

PDFS['energy-retrofit-case-study'] = dict(
    title='Case Study: 22% Energy Reduction in a 1.2 Mn Sq Ft Campus',
    subtitle='A Bengaluru technology campus and the 14 measures that delivered it in 18 months',
    kind='Case Studies',
    blocks=[
        P('Background. A 1.2 million sq ft campus with six buildings, 9,500 seats and a 1,400 TR chilled water plant was '
          'consuming 31.6 million kWh a year. Energy was the second largest operating cost after manpower. The facilities '
          'team set a target of 20% reduction with a payback under three years and no impact on comfort scores.'),
        H('Approach'),
        N('Metering first: 112 sub-meters were added over six weeks, giving a 15-minute view of chillers, AHUs, lighting and the data room.',
          'Baselining: three months of data normalised for weather and occupancy produced a clear picture of idle load.',
          'Prioritising: measures were ranked by payback and risk; operational changes came before capital works.'),
        H('Measures and results'),
        T(['Measure', 'Capex (Rs lakh)', 'Annual saving (kWh)', 'Payback'],
          [['Chiller sequencing and condenser water reset', '4', '1,480,000', '3 months'],
           ['Chilled water delta-T recovery (coil cleaning, valve fixes)', '9', '1,120,000', '7 months'],
           ['AHU schedules aligned to real occupancy', '2', '860,000', '2 months'],
           ['VFDs on secondary pumps and cooling tower fans', '38', '1,310,000', '19 months'],
           ['LED retrofit with occupancy sensors, common areas', '72', '980,000', '22 months'],
           ['Data room containment and setpoint raise to 24 deg C', '26', '640,000', '17 months'],
           ['Solar rooftop, 600 kWp (PPA, no capex)', '0', '780,000', 'immediate']],
          [220, 80, 100, 70]),
        H('Outcome'),
        P('Total energy fell from 31.6 to 24.6 million kWh (22%), avoided cost about Rs 5.6 crore a year at an average '
          'tariff of Rs 8 per kWh, and carbon avoided about 5,700 tCO2e. Comfort complaints fell 12% because the delta-T '
          'recovery fixed long-standing hot spots. Capex totalled Rs 1.51 crore, a blended payback of 11 months.'),
        H('Lessons'),
        B('Operational fixes delivered 58% of the savings for 10% of the spend',
          'Trend logs convinced the finance team faster than any estimate',
          'Tenant communication on schedule changes mattered as much as the engineering'),
    ])

PDFS['housekeeping-sla-sop'] = dict(
    title='Housekeeping Service Levels and Inspection SOP',
    subtitle='Frequencies, standards and the monthly audit method for office and campus housekeeping',
    kind='SOPs',
    blocks=[
        P('This SOP sets the minimum service levels for housekeeping at member sites and the method the facilities team '
          'uses to inspect them. It is written for a contractor-delivered service but applies equally to in-house teams.'),
        H('1. Service frequencies'),
        T(['Area', 'Task', 'Frequency'],
          [['Workstations and open offices', 'Dust, wipe, bin collection', 'Daily'],
           ['Meeting rooms', 'Reset, wipe, glass clean', 'After each use / daily'],
           ['Washrooms', 'Clean, restock, odour control', 'Hourly checks, 4 full cleans a day'],
           ['Pantries and cafeteria', 'Surface sanitising, floor scrub, bins', 'Continuous in service, deep clean nightly'],
           ['Lobby and lifts', 'Mop, polish, glass, brass', 'Every 2 hours / daily'],
           ['Windows and facade (low level)', 'Wash', 'Fortnightly']],
          [150, 190, 130]),
        H('2. Quality standards'),
        B('Floors dry, free of residue and visibly clean at 1 metre',
          'Glass and mirrors streak-free; no fingerprints on lift doors',
          'Washrooms free of odour, with soap, tissue and sanitiser available at all times',
          'No overflowing bins; bin liners changed when two-thirds full'),
        H('3. Inspection method'),
        N('Inspect 10% of each area type each week, never the same spaces in the same order.',
          'Score each item pass or fail against the standard with a photograph for every fail.',
          'Calculate the monthly score as passes divided by items inspected; target 90% or better.',
          'Share the scorecard with the supervisor within 24 hours; failed items are rectified within the shift.'),
        H('4. Consumables and chemicals'),
        B('Use only approved chemicals with safety data sheets at the point of use',
          'Colour-code cloths and mops by zone to prevent cross-contamination',
          'Track consumable use per 1,000 sq ft and investigate months that move more than 10%'),
        H('5. People'),
        P('Supervisors brief every shift on priorities, deep-clean programmes and incidents. Staff receive induction on '
          'chemicals, manual handling and waste segregation within their first week, and a refresher every six months.'),
    ])

PDFS['contractor-onboarding-process'] = dict(
    title='Contractor Onboarding Process',
    subtitle='From vendor shortlist to first day on site: documents, checks, induction and permits',
    kind='Processes',
    blocks=[
        P('A contractor who arrives without the right paperwork is a safety and legal risk. This process describes the stages '
          'a vendor passes through before any work starts on a member site. Stages one to three are done by procurement; four to '
          'six by the facilities team.'),
        H('Process map'),
        T(['Stage', 'Owner', 'Output', 'Time'],
          [['1. Pre-qualification', 'Procurement', 'Scored vendor profile; KYC and GST verified', '3 days'],
           ['2. Commercial agreement', 'Procurement / Legal', 'Signed contract with SLA and indemnities', '5 days'],
           ['3. Statutory documents', 'Vendor / HR', 'PF, ESI, labour licence, insurance, police verification', '5 days'],
           ['4. Safety induction', 'EHS', 'Induction record, PPE issued, permits explained', '1 day'],
           ['5. Access and systems', 'Security / IT', 'ID cards, biometrics, CMMS user accounts', '1 day'],
           ['6. Work permit', 'Facilities', 'Approved permit for first task', 'Same day']],
          [100, 90, 220, 60]),
        H('Document checklist'),
        B('Company registration, GST and PAN',
          'Labour licence and contractor registration under the CLRA where applicable',
          'PF and ESI registration, and the last three months of challans',
          'Insurance: workmen\'s compensation, public liability, and plant and machinery where relevant',
          'Police verification and medical fitness for each worker',
          'Trade licences for electricians, lift mechanics, high-voltage and working-at-height crews'),
        H('Induction content'),
        N('Site rules, emergency exits, assembly points and the alarm signal.',
          'Permit-to-work rules: hot work, working at height, confined space, electrical isolation.',
          'Waste handling, chemical safety and incident reporting.',
          'Behaviour on site: access control, photography, tenant sensitivity.'),
        H('Reviewing performance'),
        P('After 30 days, the facilities lead reviews attendance, incidents, work-order closure and feedback from the '
          'users served. A vendor that misses the standard receives a written improvement plan with a 30-day deadline.'),
    ])

PDFS['cmms-selection-insights'] = dict(
    title='Choosing a CMMS: What Operators Wish They Had Asked',
    subtitle='Insights from 21 Chapter members who replaced or implemented a maintenance management system',
    kind='Insights',
    blocks=[
        P('A computerised maintenance management system (CMMS) is the backbone of planned maintenance, SLA reporting and '
          'audit evidence. We asked 21 members what they would do differently. The answers were remarkably consistent: the '
          'software was rarely the problem; the data, the process and the people were.'),
        H('1. Insights from the field'),
        B('Spend the first month on the asset register. A CMMS with 60% of assets tagged and 40% unknown delivers 60% of the value at best.',
          'Mobile first. If technicians cannot close a work order on the floor with a photograph, they will close it at the end of the week from memory.',
          'Integrations pay for themselves: BMS alarms creating tickets, helpdesk to CMMS, and CMMS to the finance system for spares.',
          'Insist on a sandbox with your own data before signing.',
          'Plan for reporting early. A dashboard that mirrors the SLA scorecard avoids a monthly spreadsheet exercise.'),
        H('2. Evaluation questions'),
        T(['Area', 'Ask the vendor'],
          [['Data', 'How do we bulk-import assets with hierarchy, locations and warranties? Who owns the data on exit?'],
           ['Mobile', 'Does the app work offline? Can QR codes open the right asset and task?'],
           ['Scheduling', 'Can we define PPM by meter, calendar and condition, and see load by technician?'],
           ['Compliance', 'Does it hold statutory certificates with expiry reminders and permit-to-work records?'],
           ['Cost', 'Is pricing per user, per asset or per site? What does an extra tenant cost?'],
           ['Support', 'What is the local support team, response time and implementation plan?']],
          [70, 400]),
        H('3. Implementation roadmap'),
        N('Weeks 1 to 4: asset survey, naming standard and criticality ratings.',
          'Weeks 5 to 8: configure PPM schedules for the top 20% critical assets; train supervisors.',
          'Weeks 9 to 12: go live on one building, run daily reviews, then roll out to the rest.',
          'Month 4 onwards: add SLA reporting, spares control and cost tracking.'),
        H('4. Warning signs'),
        B('Work orders closed in bulk at month end', 'Ticket categories that nobody uses',
          'Technicians sharing one login', 'A report nobody reads'),
    ])

PDFS['data-centre-uptime-practices'] = dict(
    title='Data Centre Uptime: Operating Practices',
    subtitle='What operators of Tier III facilities do every day, week and quarter',
    kind='Best Practices',
    blocks=[
        P('Uptime in a data centre is mostly the result of discipline: knowing what changed, rehearsing failure and '
          'respecting maintenance windows. These practices come from the Data Centre Uptime Clinic held by the Hyderabad '
          'Chapter, and apply to enterprise rooms as well as colocation facilities.'),
        H('1. Daily and weekly'),
        B('Walk-through with checklist: leaks, alarms, temperatures, fuel levels, battery status',
          'Review the last 24 hours of alarms and the changes scheduled for the next 24',
          'Verify generator auto-start readiness and fuel above 80% of tank capacity',
          'Weekly test of the building management alarms to the on-call phone'),
        H('2. Change management'),
        N('Every change has a written method of procedure (MOP) with step-by-step actions, rollback and abort criteria.',
          'Changes to critical power or cooling need two engineers and a second reviewer.',
          'Freeze windows are published; no non-urgent change during quarter-end or major customer events.',
          'After the change, verify and log the as-found and as-left readings.'),
        H('3. Testing'),
        T(['Test', 'Frequency', 'Pass criterion'],
          [['Generator on load', 'Monthly, 30 minutes', 'Starts in under 10 seconds; stable voltage'],
           ['UPS battery discharge', 'Quarterly', 'At least 90% of rated autonomy'],
           ['Chiller changeover', 'Quarterly', 'No rise above 1.5 deg C in cold aisle'],
           ['Full building transfer', 'Annually', 'ATS transfer without IT impact'],
           ['Fire suppression and EPO drill', 'Annually', 'Procedure followed; no accidental release']],
          [140, 120, 210]),
        H('4. Metrics that matter'),
        B('Mean time between failures by system', 'PUE trend with load, reported monthly',
          'Change failure rate (target under 2%)', 'Incident post-mortems completed within five days'),
    ])

PDFS['occupancy-research-summary'] = dict(
    title='Hybrid Occupancy Research Summary',
    subtitle='What 14 months of badge, Wi-Fi and sensor data say about how offices are really used',
    kind='Research',
    blocks=[
        P('Between August 2025 and September 2026, six members shared anonymised occupancy data from 11 buildings in '
          'Bengaluru, Mumbai, Hyderabad and the NCR. The data cover about 18,000 employees. This summary highlights the '
          'patterns that matter for space and service planning.'),
        H('1. Weekly pattern'),
        T(['Day', 'Average occupancy', 'Share of weekly visits'],
          [['Monday', '49%', '17%'], ['Tuesday', '66%', '23%'], ['Wednesday', '69%', '24%'],
           ['Thursday', '58%', '20%'], ['Friday', '28%', '10%'], ['Saturday and Sunday', '3%', '1%']],
          [160, 150, 160]),
        H('2. Findings'),
        B('Mid-week peaks are persistent: Tuesday and Wednesday run 35 to 40 points above Friday',
          'Teams that agreed anchor days produced the highest satisfaction and the lowest idle space',
          'Seat sharing above a 0.7 ratio produced booking friction unless meeting rooms were added',
          'Visitors and contractors add 6 to 9% to peak load and are almost never in capacity models'),
        H('3. Implications for facilities'),
        N('Schedule heavy cleaning, plant maintenance and fit-out noise on Mondays and Fridays.',
          'Run HVAC on a sliding schedule linked to the booking calendar rather than a fixed time.',
          'Adjust cafeteria production using next-day bookings to cut food waste by 12 to 18%.',
          'Review lift and parking capacity at the Wednesday peak, not the average day.'),
        H('4. Limits of the data'),
        P('Badge data counts entries, not time on desk; Wi-Fi counts devices, not people. The sample excludes '
          'manufacturing and retail sites. Use the numbers to frame a pilot and verify them with your own sensors.'),
    ])

PDFS['rfp-evaluation-framework'] = dict(
    title='RFP Evaluation Framework for IFM Contracts',
    subtitle='A weighted scoring model and question set for integrated facility management tenders',
    kind='Templates',
    blocks=[
        P('Selecting an integrated facility management (IFM) provider is a decision with a five-year consequence. This '
          'framework gives procurement and facilities a shared scoring model that separates commercial, technical and '
          'delivery risk, and records the reasoning for audit.'),
        H('1. Scoring model'),
        T(['Criterion', 'Weight', 'What good looks like'],
          [['Technical approach and mobilisation plan', '25%', 'Site-specific plan, named team, risk register'],
           ['Experience and references', '15%', 'Three comparable sites; references checked by phone'],
           ['Technology and reporting', '15%', 'CMMS, mobile, SLA dashboards, API access'],
           ['Compliance and safety record', '15%', 'Clean statutory history; safety statistics available'],
           ['Commercial price (normalised)', '25%', 'Lowest compliant bid scores 100'],
           ['Social value and sustainability', '5%', 'Local hiring, training, energy and waste plan']],
          [220, 60, 190]),
        H('2. Questions to include'),
        B('Describe your first 90 days. Who is on site on day one and what is done in week one?',
          'Show a sample monthly SLA report from a comparable client (names removed)',
          'How do you control subcontractors and verify statutory documents?',
          'What is your manpower attrition and how do you retain supervisors?',
          'Explain your pricing: fixed fee, management fee, reimbursables and what you consider out of scope'),
        H('3. Evaluation process'),
        N('Compliance gate: reject bids missing mandatory documents before scoring.',
          'Independent scoring: each panel member scores alone, then the panel meets to resolve differences of more than 20 points.',
          'Site visits and presentations for the top three bidders.',
          'Best and final offer on a clarified scope, then final scoring and approval.'),
        H('4. Red flags'),
        B('A price more than 20% below the median with no explanation', 'No named site manager',
          'Reluctance to share references', 'Vague answers on statutory compliance'),
    ])

PDFS['security-incident-policy'] = dict(
    title='Security Incident Reporting Policy',
    subtitle='What counts as an incident, who reports it, and how it is handled and learned from',
    kind='Policies',
    blocks=[
        P('Policy statement: every security incident on a member site shall be reported, recorded and reviewed. Reporting is '
          'expected, not punished; the aim is to learn and prevent recurrence.'),
        H('1. What is an incident'),
        B('Unauthorised entry, tailgating or forced access', 'Theft, loss or damage of property',
          'Threats, harassment or violence involving visitors or staff',
          'Suspicious packages, vehicles or behaviour', 'Loss of an access card or master key',
          'Cyber-physical events such as tampering with CCTV, door controllers or BMS panels'),
        H('2. Severity levels'),
        T(['Level', 'Definition', 'Notify within'],
          [['1 - Critical', 'Threat to life, serious injury, major theft, bomb threat', 'Immediately by phone'],
           ['2 - High', 'Forced entry, significant damage, harassment complaint', '1 hour'],
           ['3 - Medium', 'Policy breach, lost access card, minor theft', 'Same shift'],
           ['4 - Low', 'Near miss, unlocked door, observation', '24 hours']],
          [90, 270, 110]),
        H('3. Reporting and response'),
        N('Report to the security control room or call the emergency number; give time, location and what was seen.',
          'The shift supervisor secures the area, preserves CCTV footage and records the first account.',
          'Critical and high incidents are escalated to the Head of Facilities and HR, and to the police where required.',
          'A written report is completed within 24 hours with facts, actions taken and open questions.'),
        H('4. Review'),
        P('Incidents are reviewed monthly by the facilities and HR leads. Themes (for example repeated tailgating at one '
          'door) lead to a corrective action with an owner and date. Anonymised summaries are shared with all staff each quarter.'),
    ])

# ---------------------------------------------------------------------------
# Chapter whitepapers: one per designed city, same structure with the city's own text
# ---------------------------------------------------------------------------

CITY = {
    'bengaluru': dict(
        name='Bengaluru', market='technology campuses and Global Capability Centres',
        stats=[['Seats in GCCs and tech campuses', '1.4 million'], ['Grade-A office stock', '178 million sq ft'],
               ['Median IFM cost per sq ft per month', 'Rs 36'], ['Peak mid-week occupancy', '63%'],
               ['Share of campuses with BMS-integrated CMMS', '54%']],
        themes=['Traffic and shuttle planning drive employee experience more than any amenity',
                'Campus operators now buy energy through open access and rooftop solar PPAs',
                'Cafeteria and housekeeping vendors are consolidating into integrated contracts',
                'Heavy monsoon rainfall tests drainage, basement and facade maintenance each July']),
    'mumbai': dict(
        name='Mumbai', market='high-rise towers, BFSI campuses and coastal-climate buildings',
        stats=[['Grade-A office stock', '121 million sq ft'], ['Share of stock in high-rise towers (30+ floors)', '37%'],
               ['Median IFM cost per sq ft per month', 'Rs 44'], ['Lift waiting-time complaints per 1,000 seats', '21'],
               ['Share of towers with a full facade maintenance plan', '48%']],
        themes=['Vertical transport capacity is the binding constraint at the 9 to 10 am peak',
                'Coastal air accelerates corrosion on plant, railings and curtain-wall fixings',
                'BFSI security and business-continuity rules shape every service contract',
                'Space is expensive, so fit-out density and meeting-room supply are board-level topics']),
    'delhi-ncr': dict(
        name='Delhi NCR', market='corporate parks in Gurugram and Noida, and large campuses',
        stats=[['Grade-A office stock', '132 million sq ft'], ['Median IFM cost per sq ft per month', 'Rs 33'],
               ['Days a year with air quality in the poor category or worse', '161'],
               ['Share of buildings with MERV 13 or better filtration', '41%'],
               ['Median DG run-hours per site per month', '38']],
        themes=['Winter air quality changes ventilation, filtration and outdoor-work rules',
                'Grid reliability varies by sector, so DG and UPS strategies differ widely',
                'Large corporate parks need shuttle, security and landscape services at campus scale',
                'Summer peak cooling load and water stress push chiller efficiency and STP reuse']),
    'hyderabad': dict(
        name='Hyderabad', market='hyperscale GCC campuses, new builds and smart-building programmes',
        stats=[['Grade-A office stock', '108 million sq ft'], ['New supply under construction', '26 million sq ft'],
               ['Median IFM cost per sq ft per month', 'Rs 31'], ['Share of new buildings with IGBC or LEED rating', '72%'],
               ['Share of campuses piloting AI-based energy optimisation', '29%']],
        themes=['New buildings arrive with sophisticated systems and thin operations teams',
                'Data centres and life-science campuses raise the bar on resilience and compliance',
                'Smart-building programmes depend on clean BMS data and clear ownership',
                'Rapid hiring means handover quality decides first-year performance']),
}


def whitepaper(slug):
    c = CITY[slug]
    return dict(
        title='%s Workplace Experience Benchmark 2026' % c['name'],
        subtitle='Market notes and operating metrics for %s from the ICR %s Chapter' % (c['name'], c['name']),
        kind='Research',
        blocks=[
            P('This note summarises what ICR %s Chapter members told us in 2026 about running %s. It is written for '
              'facilities leaders, procurement teams and service providers who want a shared set of reference numbers '
              'before the next budget cycle.' % (c['name'], c['market'])),
            H('1. Market snapshot'),
            T(['Metric', 'Value'], c['stats'], [300, 170]),
            H('2. Themes from the Chapter'),
            B(*c['themes']),
            H('3. Operating priorities for the year'),
            N('Raise preventive-maintenance compliance to 95% and report it monthly.',
              'Move to a single SLA scorecard across hard and soft services.',
              'Meter the largest controllable loads and publish the intensity per seat.',
              'Run one drill each quarter: fire, power failure, lift entrapment or water ingress.'),
            H('4. How to use these numbers'),
            P('Values are medians from member submissions validated by the Chapter committee and are indicative, not '
              'contractual. Use them to start a conversation with your provider, and then measure your own site. '
              'Members who would like to contribute data for the next edition should contact the committee.'),
        ])
