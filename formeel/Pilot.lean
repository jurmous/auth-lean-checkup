import Std

set_option autoImplicit false

namespace GFPilot

abbrev Time := Nat
abbrev URA := Nat
abbrev Service := Nat
abbrev Client := Nat
abbrev Certificate := Nat
abbrev Resource := Nat
abbrev Issuer := Nat
abbrev Identifier := Nat

inductive Profile where | bgz | eOverdracht
  deriving DecidableEq
inductive Direction where | notify | retrieve
  deriving DecidableEq
inductive Role where | custodian | user
  deriving DecidableEq

def Direction.clientRole : Direction → Role
  | .notify => .custodian
  | .retrieve => .user

def Direction.peerRole : Direction → Role
  | .notify => .user
  | .retrieve => .custodian

structure Target where
  provider : URA
  resource : Resource
  deriving DecidableEq

structure Intent where
  profile : Profile
  direction : Direction
  subject : URA
  target : Target
  deriving DecidableEq

structure MandateRequest where
  provider : URA
  service : Service
  roles : List Role
  deriving DecidableEq

structure Mandate where
  id : Identifier
  issuer : Issuer
  request : MandateRequest
  signer : Certificate
  issued : Time
  starts : Time
  ends : Time
  deriving DecidableEq

structure Approval where
  provider : URA
  service : Service
  roles : List Role
  starts : Time
  ends : Time
  deriving DecidableEq

structure CredentialGrant where
  issuer : Issuer
  request : MandateRequest
  client : Client
  certificate : Certificate
  starts : Time
  ends : Time
  deriving DecidableEq

structure Pending where
  id : Identifier
  grant : CredentialGrant
  opened : Time
  ends : Time
  interval : Time
  deriving DecidableEq

structure ProtectedMetadata where
  resource : Resource
  peerCertificate : Certificate
  servers : List Issuer
  mandates : List Mandate
  deriving DecidableEq

structure PeerSnapshot where
  metadata : ProtectedMetadata
  fetched : Time
  cacheUntil : Time
  deriving DecidableEq

structure ClientMetadata where
  client : Client
  host : Nat
  tlsClientAuth : Bool
  jwtBearer : Bool
  deriving DecidableEq

structure ClientSnapshot where
  issuer : Issuer
  metadata : ClientMetadata
  fetched : Time
  freshUntil : Time
  deriving DecidableEq

inductive MetadataError where | invalidClient | unavailable
  deriving DecidableEq

inductive FetchResult where
  | document (metadata : ClientMetadata) (maxAge : Option Time)
  | invalid
  | transient
  deriving DecidableEq

structure Assertion where
  intent : Intent
  issuer : Issuer
  endpoint : Nat
  client : Client
  certificate : Certificate
  mandate : Mandate
  jti : Identifier
  issuedAt : Time
  expires : Time
  locations : List Resource
  deriving DecidableEq

structure Token where
  id : Identifier
  assertion : Assertion
  issued : Time
  ends : Time
  deriving DecidableEq

inductive Operation where
  | notification (id : Identifier)
  | read (id : Identifier)
  | search (query : Identifier)
  | update (id : Identifier)
  deriving DecidableEq

def Operation.direction : Operation → Direction
  | .notification _ => .notify
  | .read _ | .search _ | .update _ => .retrieve

structure Availability where
  id : Identifier
  profile : Profile
  source : Target
  recipient : URA
  dataset : Identifier
  patient : Identifier
  starts : Time
  ends : Time
  operations : List Operation
  deriving DecidableEq

structure AccessRequest where
  intent : Intent
  certificate : Certificate
  transfer : Identifier
  operation : Operation
  deriving DecidableEq

structure Notification where
  id : Identifier
  profile : Profile
  source : Target
  recipient : Target
  transfer : Identifier
  deriving DecidableEq

/-- Validated inputs at the wire and care-profile boundary. Each predicate has
    its own actor, inputs and observation time. -/
structure Policy where
  clientTLS : Time → Certificate → Prop
  serverTLS : Time → Certificate → Prop
  providerOfSigner : Certificate → Option URA
  serviceOfTLS : Certificate → Option Service
  certificateEnds : Certificate → Time
  signerStatusGood : Time → Certificate → Prop
  clientHost : Client → Option Nat
  certificateHasDNS : Certificate → Nat → Prop
  mandateAuthentic : Mandate → Prop
  assertionAuthentic : Assertion → Prop
  clientMetadataFetch : Time → Issuer → Client → FetchResult → Prop
  protectedMetadataFetch : Time → ProtectedMetadata → Prop
  asEndpoint : Time → Issuer → Nat → Prop
  serves : Time → Issuer → Target → Prop
  registeredIssuer : Time → URA → Issuer → Prop
  knownIssuer : Time → URA → Service → Issuer → Prop
  issuerTransportOK : Time → Issuer → Prop
  canSign : Issuer → URA → Certificate → Prop
  selfIssuer : Issuer → Service → Prop
  approvalInput : Time → Approval → Prop
  withdrawalInput : Time → URA → Service → Prop
  availabilityInput : Time → Identifier → Option Availability → Prop
  directoryTarget : Time → Profile → Target → Prop
  notificationOK : Time → Notification → Prop
  retrievalOK : Time → Availability → Operation → Prop
  tokenVerified : Time → Token → Prop
  pendingLifetime : Time
  issuanceTokenLifetime : Time
  accessTokenLifetime : Time
  capMandateAtApproval : Bool
  capTokenAtMandate : Bool

inductive Event where
  | issuerFound (provider : URA) (service : Service) (issuer : Issuer)
  | approval (provider : URA) (service : Service) (value : Option Approval)
  | credentialAuthorized (grant : CredentialGrant)
  | pending (transaction : Pending)
  | polled (id : Identifier) (atTime : Time)
  | closed (id : Identifier)
  | mandateIssued (mandate : Mandate)
  | availability (id : Identifier) (value : Option Availability)
  | protectedFetched (snapshot : PeerSnapshot)
  | peerChecked (intent : Intent) (issuer : Issuer) (endpoint : Nat) (atTime : Time)
  | clientFetched (snapshot : ClientSnapshot)
  | clientChecked (issuer : Issuer) (client : Client) (certificate : Certificate) (atTime : Time)
  | metadataFailed (issuer : Issuer) (client : Client) (error : MetadataError)
  | reserved (assertion : Assertion) (atTime : Time)
  | denied (assertion : Assertion) (atTime : Time)
  | tokenIssued (token : Token)
  | notificationAccepted (notification : Notification)
  | accepted (request : AccessRequest) (token : Token) (atTime : Time)
  deriving DecidableEq

structure State where
  now : Time
  history : List Event

def State.record (s : State) (event : Event) : State :=
  ⟨s.now, event :: s.history⟩

def State.currentApproval (s : State) (r : MandateRequest) : Option Approval :=
  (s.history.findSome? fun event =>
    match event with
    | .approval provider service value =>
      if provider = r.provider ∧ service = r.service then some value else none
    | _ => none).join

def State.currentAvailability (s : State) (id : Identifier) : Option Availability :=
  (s.history.findSome? fun event =>
    match event with
    | .availability key value => if key = id then some value else none
    | _ => none).join

def State.lastPoll (s : State) (id : Identifier) : Option Time :=
  s.history.findSome? fun event =>
    match event with
    | .polled key time => if key = id then some time else none
    | _ => none

def ApprovalApplies (s : State) (r : MandateRequest) (a : Approval) : Prop :=
  s.currentApproval r = some a ∧ a.provider = r.provider ∧ a.service = r.service ∧
    a.starts ≤ s.now ∧ s.now < a.ends ∧ r.roles ≠ [] ∧
    ∀ role ∈ r.roles, role ∈ a.roles

def ValidMandate (p : Policy) (now : Time) (m : Mandate) : Prop :=
  p.mandateAuthentic m ∧ p.providerOfSigner m.signer = some m.request.provider ∧
  p.signerStatusGood now m.signer ∧ m.issued ≤ now ∧ m.starts ≤ now ∧
  now < m.ends ∧ m.ends ≤ m.starts + 92 * 86400 ∧ m.ends ≤ p.certificateEnds m.signer

def Mint (p : Policy) (s : State) (issuer : Issuer) (r : MandateRequest) (m : Mandate) : Prop :=
  m.issuer = issuer ∧ m.request = r ∧ p.canSign issuer r.provider m.signer ∧
  m.issued = s.now ∧ ValidMandate p s.now m ∧
  (∃ a, ApprovalApplies s r a ∧ (p.capMandateAtApproval = true → m.ends ≤ a.ends)) ∧
  (∀ prior, Event.mandateIssued prior ∈ s.history → prior.id ≠ m.id)

def ValidCredentialGrant (p : Policy) (s : State) (g : CredentialGrant) : Prop :=
  .credentialAuthorized g ∈ s.history ∧ g.starts ≤ s.now ∧ s.now < g.ends ∧
    p.clientTLS s.now g.certificate ∧ p.issuerTransportOK s.now g.issuer

def SameCredentialContext (before after : CredentialGrant) : Prop :=
  before.issuer = after.issuer ∧ before.request = after.request ∧
    before.client = after.client ∧ before.certificate = after.certificate

def PendingReady (s : State) (job : Pending) : Prop :=
  .pending job ∈ s.history ∧ .closed job.id ∉ s.history ∧ s.now < job.ends ∧
    job.interval ≤ s.now - (s.lastPoll job.id).getD job.opened

def BoundClient (p : Policy) (s : State) (client : Client) (certificate : Certificate) : Prop :=
  p.clientTLS s.now certificate ∧
    ∃ host, p.clientHost client = some host ∧ p.certificateHasDNS certificate host

def MatchingClientMetadata (p : Policy) (client : Client) (m : ClientMetadata) : Prop :=
  m.client = client ∧ p.clientHost client = some m.host ∧
    m.tlsClientAuth = true ∧ m.jwtBearer = true

def LatestClientSnapshot (s : State) (issuer : Issuer) (client : Client) : Option ClientSnapshot :=
  (s.history.findSome? fun event =>
    match event with
    | .clientFetched snapshot =>
      if snapshot.issuer = issuer ∧ snapshot.metadata.client = client then some (some snapshot) else none
    | .metadataFailed failedIssuer failedClient .invalidClient =>
      if failedIssuer = issuer ∧ failedClient = client then some none else none
    | _ => none).join

def PeerRoute (p : Policy) (s : State) (intent : Intent) : Prop :=
  match intent.direction with
  | .notify => p.directoryTarget s.now intent.profile intent.target
  | .retrieve =>
    ∃ notification,
      .notificationAccepted notification ∈ s.history ∧
      notification.profile = intent.profile ∧ notification.recipient.provider = intent.subject ∧
      notification.source = intent.target

def PeerCheck (p : Policy) (s : State) (intent : Intent) (issuer : Issuer)
    (endpoint : Nat) (snapshot : PeerSnapshot) (mandate : Mandate) : Prop :=
  PeerRoute p s intent ∧ .protectedFetched snapshot ∈ s.history ∧
    (snapshot.fetched = s.now ∨ s.now < snapshot.cacheUntil) ∧
    snapshot.metadata.resource = intent.target.resource ∧ issuer ∈ snapshot.metadata.servers ∧
    p.asEndpoint s.now issuer endpoint ∧ p.serverTLS s.now snapshot.metadata.peerCertificate ∧
    mandate ∈ snapshot.metadata.mandates ∧ ValidMandate p s.now mandate ∧
    mandate.request.provider = intent.target.provider ∧
    p.serviceOfTLS snapshot.metadata.peerCertificate = some mandate.request.service ∧
    intent.direction.peerRole ∈ mandate.request.roles

def ValidEnvelope (p : Policy) (s : State) (a : Assertion) : Prop :=
  .peerChecked a.intent a.issuer a.endpoint s.now ∈ s.history ∧
    .clientChecked a.issuer a.client a.certificate s.now ∈ s.history ∧
    BoundClient p s a.client a.certificate ∧ p.assertionAuthentic a ∧
    a.issuedAt ≤ s.now + 60 ∧ a.issuedAt < a.expires ∧
    s.now < a.expires ∧ a.expires ≤ a.issuedAt + 300

def LiveReservation (s : State) (a : Assertion) : Prop :=
  ∃ prior atTime, .reserved prior atTime ∈ s.history ∧ prior.issuer = a.issuer ∧
    prior.client = a.client ∧ prior.jti = a.jti ∧ s.now < prior.expires

def UnfinishedReservation (s : State) (a : Assertion) : Prop :=
  .reserved a s.now ∈ s.history ∧ .denied a s.now ∉ s.history ∧
    ∀ token, .tokenIssued token ∈ s.history → token.assertion = a → token.issued ≠ s.now

def GrantChecks (p : Policy) (s : State) (a : Assertion) : Prop :=
  ValidMandate p s.now a.mandate ∧ a.mandate.request.provider = a.intent.subject ∧
    p.serviceOfTLS a.certificate = some a.mandate.request.service ∧
    a.intent.direction.clientRole ∈ a.mandate.request.roles ∧
    a.intent.target.resource ∈ a.locations ∧
    ∀ resource ∈ a.locations, p.serves s.now a.issuer ⟨a.intent.target.provider, resource⟩

def AcceptTransport (p : Policy) (s : State) (r : AccessRequest) (t : Token) : Prop :=
  .tokenIssued t ∈ s.history ∧ p.tokenVerified s.now t ∧
    t.issued ≤ s.now ∧ s.now < t.ends ∧ p.clientTLS s.now r.certificate ∧
    r.certificate = t.assertion.certificate ∧ r.intent = t.assertion.intent ∧
    r.intent.target.resource ∈ t.assertion.locations ∧
    p.serves s.now t.assertion.issuer r.intent.target ∧
    r.intent.direction.clientRole ∈ t.assertion.mandate.request.roles

def AvailabilityFor (p : Policy) (s : State) (r : AccessRequest) (a : Availability) : Prop :=
  s.currentAvailability r.transfer = some a ∧ a.id = r.transfer ∧
    a.profile = r.intent.profile ∧ a.source = r.intent.target ∧ a.recipient = r.intent.subject ∧
    a.starts ≤ s.now ∧ s.now < a.ends ∧ r.operation.direction = .retrieve ∧ r.operation ∈ a.operations ∧
    p.retrievalOK s.now a r.operation

/-- Relational semantics. Only a constructor that establishes the rules can add
    the corresponding successful event to a reachable history. -/
inductive Step (p : Policy) (s : State) : State → Prop where
  | tick (next : Time) : s.now ≤ next → Step p s ⟨next, s.history⟩
  | discover (provider : URA) (service : Service) (issuer : Issuer) :
      (p.registeredIssuer s.now provider issuer ∨ p.knownIssuer s.now provider service issuer) →
      Step p s (s.record (.issuerFound provider service issuer))
  | approve (a : Approval) :
      p.approvalInput s.now a → a.starts < a.ends →
      Step p s (s.record (.approval a.provider a.service (some a)))
  | withdraw (provider : URA) (service : Service) :
      p.withdrawalInput s.now provider service → Step p s (s.record (.approval provider service none))
  | credentialGrant (g : CredentialGrant) :
      .issuerFound g.request.provider g.request.service g.issuer ∈ s.history →
      BoundClient p s g.client g.certificate →
      p.issuerTransportOK s.now g.issuer →
      p.serviceOfTLS g.certificate = some g.request.service →
      (∃ signer, p.canSign g.issuer g.request.provider signer) →
      g.request.roles ≠ [] → g.starts = s.now → s.now < g.ends →
      g.ends ≤ s.now + p.issuanceTokenLifetime →
      Step p s (s.record (.credentialAuthorized g))
  | issueImmediate (g : CredentialGrant) (m : Mandate) :
      ValidCredentialGrant p s g → Mint p s g.issuer g.request m →
      Step p s (s.record (.mandateIssued m))
  | issueSelf (issuer : Issuer) (r : MandateRequest) (m : Mandate) :
      p.selfIssuer issuer r.service → Mint p s issuer r m →
      Step p s (s.record (.mandateIssued m))
  | defer (job : Pending) :
      ValidCredentialGrant p s job.grant → job.opened = s.now →
      (¬ ∃ a, ApprovalApplies s job.grant.request a) →
      (∀ old, .pending old ∈ s.history → old.id ≠ job.id) →
      0 < job.interval → s.now < job.ends → job.ends ≤ s.now + p.pendingLifetime →
      Step p s (s.record (.pending job))
  | pollPending (job : Pending) (g : CredentialGrant) :
      PendingReady s job → ValidCredentialGrant p s g → SameCredentialContext job.grant g →
      (¬ ∃ a, ApprovalApplies s job.grant.request a) →
      Step p s (s.record (.polled job.id s.now))
  | issueDeferred (job : Pending) (g : CredentialGrant) (m : Mandate) :
      PendingReady s job → ValidCredentialGrant p s g → SameCredentialContext job.grant g →
      Mint p s g.issuer g.request m →
      Step p s ((s.record (.closed job.id)).record (.mandateIssued m))
  | closeDeferred (job : Pending) :
      .pending job ∈ s.history → .closed job.id ∉ s.history →
      (job.ends ≤ s.now ∨ ∃ approval, .approval job.grant.request.provider
        job.grant.request.service approval ∈ s.history ∧ approval = none ∧
        s.currentApproval job.grant.request = none) →
      Step p s (s.record (.closed job.id))
  | publishAvailability (id : Identifier) (value : Option Availability) :
      p.availabilityInput s.now id value →
      Step p s (s.record (.availability id value))
  | readProtected (snapshot : PeerSnapshot) :
      p.protectedMetadataFetch s.now snapshot.metadata →
      p.serverTLS s.now snapshot.metadata.peerCertificate →
      snapshot.fetched = s.now → s.now ≤ snapshot.cacheUntil →
      snapshot.cacheUntil ≤ s.now + 86400 →
      Step p s (s.record (.protectedFetched snapshot))
  | verifyPeer (intent : Intent) (issuer : Issuer) (endpoint : Nat)
      (snapshot : PeerSnapshot) (mandate : Mandate) :
      PeerCheck p s intent issuer endpoint snapshot mandate →
      Step p s (s.record (.peerChecked intent issuer endpoint s.now))
  | fetchClient (issuer : Issuer) (client : Client) (certificate : Certificate)
      (metadata : ClientMetadata) (maxAge : Option Time) :
      BoundClient p s client certificate →
      p.clientMetadataFetch s.now issuer client (.document metadata maxAge) →
      MatchingClientMetadata p client metadata →
      Step p s ((s.record (.clientFetched
        ⟨issuer, metadata, s.now, s.now + min (maxAge.getD 3600) 86400⟩)).record
        (.clientChecked issuer client certificate s.now))
  | useCachedClient (issuer : Issuer) (client : Client) (certificate : Certificate)
      (snapshot : ClientSnapshot) :
      BoundClient p s client certificate →
      LatestClientSnapshot s issuer client = some snapshot →
      MatchingClientMetadata p client snapshot.metadata → s.now < snapshot.freshUntil →
      Step p s (s.record (.clientChecked issuer client certificate s.now))
  | useStaleClient (issuer : Issuer) (client : Client) (certificate : Certificate)
      (snapshot : ClientSnapshot) :
      BoundClient p s client certificate →
      p.clientMetadataFetch s.now issuer client .transient →
      LatestClientSnapshot s issuer client = some snapshot →
      MatchingClientMetadata p client snapshot.metadata →
      snapshot.freshUntil ≤ s.now → s.now < snapshot.fetched + 86400 →
      Step p s (s.record (.clientChecked issuer client certificate s.now))
  | fetchInvalid (issuer : Issuer) (client : Client) (certificate : Certificate) :
      BoundClient p s client certificate →
      p.clientMetadataFetch s.now issuer client .invalid →
      Step p s (s.record (.metadataFailed issuer client .invalidClient))
  | fetchUnavailable (issuer : Issuer) (client : Client) (certificate : Certificate) :
      BoundClient p s client certificate →
      p.clientMetadataFetch s.now issuer client .transient →
      (∀ snapshot, LatestClientSnapshot s issuer client = some snapshot →
        snapshot.fetched + 86400 ≤ s.now) →
      Step p s (s.record (.metadataFailed issuer client .unavailable))
  | reserve (a : Assertion) :
      ValidEnvelope p s a → (¬ LiveReservation s a) →
      Step p s (s.record (.reserved a s.now))
  | rejectGrant (a : Assertion) :
      UnfinishedReservation s a → (¬ GrantChecks p s a) →
      Step p s (s.record (.denied a s.now))
  | issueToken (t : Token) :
      ValidEnvelope p s t.assertion → UnfinishedReservation s t.assertion →
      GrantChecks p s t.assertion → t.issued = s.now → s.now < t.ends →
      t.ends ≤ s.now + p.accessTokenLifetime →
      (p.capTokenAtMandate = true → t.ends ≤ t.assertion.mandate.ends) →
      (∀ prior, .tokenIssued prior ∈ s.history → prior.id ≠ t.id) →
      Step p s (s.record (.tokenIssued t))
  | acceptNotification (r : AccessRequest) (t : Token) (n : Notification) :
      AcceptTransport p s r t → r.intent.direction = .notify →
      r.operation = .notification n.id → r.transfer = n.transfer →
      n.profile = r.intent.profile → n.source.provider = r.intent.subject →
      n.recipient = r.intent.target → p.notificationOK s.now n →
      Step p s ((s.record (.notificationAccepted n)).record (.accepted r t s.now))
  | acceptRetrieval (r : AccessRequest) (t : Token) (a : Availability) :
      AcceptTransport p s r t → r.intent.direction = .retrieve → AvailabilityFor p s r a →
      Step p s (s.record (.accepted r t s.now))

inductive Reachable (p : Policy) : State → Prop where
  | initial : Reachable p ⟨0, []⟩
  | advance {s next : State} : Reachable p s → Step p s next → Reachable p next

theorem history_survives_step {p : Policy} {s next : State} {event : Event}
    (step : Step p s next) (known : event ∈ s.history) : event ∈ next.history := by
  cases step <;> simp_all [State.record]

theorem time_monotone_step {p : Policy} {s next : State} (step : Step p s next) :
    s.now ≤ next.now := by
  cases step <;> simp_all [State.record]

theorem verified_peer_has_snapshot {p : Policy} {s : State} {intent : Intent}
    {issuer : Issuer} {endpoint : Nat} {checked : Time}
    (reachable : Reachable p s) (recorded : .peerChecked intent issuer endpoint checked ∈ s.history) :
    ∃ before snapshot mandate, Reachable p before ∧ before.now = checked ∧
      PeerCheck p before intent issuer endpoint snapshot mandate := by
  induction reachable with
  | initial => simp at recorded
  | @advance before next earlier step ih =>
    cases step <;> simp [State.record] at recorded
    all_goals first
      | exact ih recorded
      | rcases recorded with ⟨rfl, rfl, rfl, rfl⟩ | recorded
        · exact ⟨before, _, _, earlier, rfl, by assumption⟩
        · exact ih recorded

theorem credential_authorization_has_discovery {p : Policy} {s : State} {g : CredentialGrant}
    (reachable : Reachable p s) (recorded : .credentialAuthorized g ∈ s.history) :
    ∃ before, Reachable p before ∧
      .issuerFound g.request.provider g.request.service g.issuer ∈ before.history ∧
      BoundClient p before g.client g.certificate ∧
      p.serviceOfTLS g.certificate = some g.request.service := by
  induction reachable with
  | initial => simp at recorded
  | @advance before next earlier step ih =>
    cases step <;> simp [State.record] at recorded
    all_goals first
      | exact ih recorded
      | rcases recorded with rfl | recorded
        · exact ⟨before, earlier, by assumption, by assumption, by assumption⟩
        · exact ih recorded

def EnrollmentEvidence (p : Policy) (before : State) (m : Mandate) : Prop :=
  p.selfIssuer m.issuer m.request.service ∨
    ∃ g, m.issuer = g.issuer ∧ m.request = g.request ∧ ValidCredentialGrant p before g

theorem issued_mandate_has_enrollment {p : Policy} {s : State} {m : Mandate}
    (reachable : Reachable p s) (recorded : .mandateIssued m ∈ s.history) :
    ∃ before, Reachable p before ∧ Mint p before m.issuer m.request m ∧
      EnrollmentEvidence p before m := by
  induction reachable with
  | initial => simp at recorded
  | @advance before next earlier step ih =>
    cases step <;> simp [State.record] at recorded
    all_goals first
      | exact ih recorded
      | rcases recorded with rfl | recorded
        · rename_i mint
          refine ⟨before, earlier, ?_, ?_⟩
          · rcases mint with ⟨hi, hr, rest⟩
            rw [hi, hr]
            exact ⟨hi, hr, rest⟩
          · first
            | exact Or.inr ⟨_, mint.1, mint.2.1, by assumption⟩
            | rw [EnrollmentEvidence, mint.1, mint.2.1]
              exact Or.inl (by assumption)
        · exact ih recorded

theorem issued_mandate_has_approval {p : Policy} {s : State} {m : Mandate}
    (reachable : Reachable p s) (recorded : .mandateIssued m ∈ s.history) :
    ∃ before, Reachable p before ∧ Mint p before m.issuer m.request m := by
  obtain ⟨before, prior, mint, _⟩ := issued_mandate_has_enrollment reachable recorded
  exact ⟨before, prior, mint⟩

theorem issued_token_has_checks {p : Policy} {s : State} {t : Token}
    (reachable : Reachable p s) (recorded : .tokenIssued t ∈ s.history) :
    ∃ before, Reachable p before ∧ t.issued = before.now ∧
      ValidEnvelope p before t.assertion ∧ UnfinishedReservation before t.assertion ∧
      GrantChecks p before t.assertion ∧ before.now < t.ends ∧
      t.ends ≤ before.now + p.accessTokenLifetime ∧
      (p.capTokenAtMandate = true → t.ends ≤ t.assertion.mandate.ends) := by
  induction reachable with
  | initial => simp at recorded
  | @advance before next earlier step ih =>
    cases step <;> simp [State.record] at recorded
    all_goals first
      | exact ih recorded
      | rcases recorded with rfl | recorded
        · exact ⟨before, earlier, by assumption, by assumption, by assumption,
            by assumption, by assumption, by assumption, by assumption⟩
        · exact ih recorded

def CareCheck (p : Policy) (s : State) (r : AccessRequest) : Prop :=
  match r.intent.direction with
  | .notify =>
    ∃ n : Notification, r.operation = .notification n.id ∧ r.transfer = n.transfer ∧
      n.profile = r.intent.profile ∧ n.source.provider = r.intent.subject ∧
      n.recipient = r.intent.target ∧ p.notificationOK s.now n
  | .retrieve => ∃ a, AvailabilityFor p s r a

theorem accepted_has_checks {p : Policy} {s : State} {r : AccessRequest} {t : Token}
    {atTime : Time} (reachable : Reachable p s) (recorded : .accepted r t atTime ∈ s.history) :
    ∃ before, Reachable p before ∧ before.now = atTime ∧
      AcceptTransport p before r t ∧ CareCheck p before r := by
  induction reachable with
  | initial => simp at recorded
  | @advance before next earlier step ih =>
    cases step <;> simp [State.record] at recorded
    all_goals first
      | exact ih recorded
      | rcases recorded with ⟨rfl, rfl, rfl⟩ | recorded
        · refine ⟨before, earlier, rfl, by assumption, ?_⟩
          first
          | have direction : r.intent.direction = .notify := by assumption
            unfold CareCheck
            rw [direction]
            exact ⟨_, by assumption, by assumption, by assumption, by assumption,
              by assumption, by assumption⟩
          | have direction : r.intent.direction = .retrieve := by assumption
            unfold CareCheck
            rw [direction]
            exact ⟨_, by assumption⟩
        · exact ih recorded

def ClientMetadataEvidence (p : Policy) (before : State) (issuer : Issuer)
    (client : Client) (certificate : Certificate) : Prop :=
  BoundClient p before client certificate ∧
    ∃ metadata, MatchingClientMetadata p client metadata ∧
      ((∃ maxAge, p.clientMetadataFetch before.now issuer client (.document metadata maxAge)) ∨
        ∃ snapshot, LatestClientSnapshot before issuer client = some snapshot ∧
          snapshot.metadata = metadata ∧
          (before.now < snapshot.freshUntil ∨
            (p.clientMetadataFetch before.now issuer client .transient ∧
              snapshot.freshUntil ≤ before.now ∧ before.now < snapshot.fetched + 86400)))

theorem verified_client_has_metadata {p : Policy} {s : State} {issuer : Issuer}
    {client : Client} {certificate : Certificate} {atTime : Time}
    (reachable : Reachable p s) (recorded : .clientChecked issuer client certificate atTime ∈ s.history) :
    ∃ before, Reachable p before ∧ before.now = atTime ∧
      ClientMetadataEvidence p before issuer client certificate := by
  induction reachable with
  | initial => simp at recorded
  | @advance before next earlier step ih =>
    cases step <;> simp [State.record] at recorded
    all_goals first
      | exact ih recorded
      | rcases recorded with ⟨rfl, rfl, rfl, rfl⟩ | recorded
        · refine ⟨before, earlier, rfl, by assumption, _, by assumption, ?_⟩
          first
          | exact Or.inl ⟨_, by assumption⟩
          | exact Or.inr ⟨_, by assumption, rfl, Or.inl (by assumption)⟩
          | exact Or.inr ⟨_, by assumption, rfl, Or.inr
              ⟨by assumption, by assumption, by assumption⟩⟩
        · exact ih recorded

/-- Main theorem. Every successful resource request has a valid issuance and
    prior peer/client checks, and satisfies the care contract at use time. -/
theorem accepted_exchange_chain {p : Policy} {s : State} {r : AccessRequest} {t : Token}
    {atTime : Time} (reachable : Reachable p s) (recorded : .accepted r t atTime ∈ s.history) :
    ∃ useState issuance peerState clientState snapshot peerMandate,
      Reachable p useState ∧ Reachable p issuance ∧ Reachable p peerState ∧
      Reachable p clientState ∧ useState.now = atTime ∧ t.issued = issuance.now ∧
      peerState.now = issuance.now ∧ clientState.now = issuance.now ∧
      AcceptTransport p useState r t ∧ CareCheck p useState r ∧
      ValidEnvelope p issuance t.assertion ∧ UnfinishedReservation issuance t.assertion ∧
      GrantChecks p issuance t.assertion ∧
      PeerCheck p peerState t.assertion.intent t.assertion.issuer t.assertion.endpoint snapshot peerMandate ∧
      ClientMetadataEvidence p clientState t.assertion.issuer t.assertion.client t.assertion.certificate := by
  obtain ⟨useState, useReachable, useTime, accept, care⟩ := accepted_has_checks reachable recorded
  obtain ⟨issuance, issueReachable, issuedTime, envelope, reserve, grant, _⟩ :=
    issued_token_has_checks useReachable accept.1
  obtain ⟨peerState, snapshot, peerMandate, peerReachable, peerTime, peer⟩ :=
    verified_peer_has_snapshot issueReachable envelope.1
  obtain ⟨clientState, clientReachable, clientTime, metadata⟩ :=
    verified_client_has_metadata issueReachable envelope.2.1
  exact ⟨useState, issuance, peerState, clientState, snapshot, peerMandate,
    useReachable, issueReachable, peerReachable, clientReachable, useTime,
    issuedTime, peerTime, clientTime, accept, care, envelope, reserve, grant, peer, metadata⟩

theorem accepted_before_mandate_expiry {p : Policy} {s : State} {r : AccessRequest}
    {t : Token} {atTime : Time} (policy : p.capTokenAtMandate = true)
    (reachable : Reachable p s) (recorded : .accepted r t atTime ∈ s.history) :
    atTime < t.assertion.mandate.ends := by
  obtain ⟨useState, useReachable, rfl, accept, _⟩ := accepted_has_checks reachable recorded
  obtain ⟨_, _, _, _, _, _, _, _, cap⟩ := issued_token_has_checks useReachable accept.1
  exact Nat.lt_of_lt_of_le accept.2.2.2.1 (cap policy)

theorem accepted_local_mandate_has_enrollment {p : Policy} {s : State} {r : AccessRequest}
    {t : Token} {atTime : Time} (reachable : Reachable p s)
    (accepted : .accepted r t atTime ∈ s.history)
    (localIssue : .mandateIssued t.assertion.mandate ∈ s.history) :
    ∃ useState enrollment, Reachable p useState ∧ Reachable p enrollment ∧
      useState.now = atTime ∧ AcceptTransport p useState r t ∧ CareCheck p useState r ∧
      Mint p enrollment t.assertion.mandate.issuer t.assertion.mandate.request t.assertion.mandate ∧
      EnrollmentEvidence p enrollment t.assertion.mandate := by
  obtain ⟨useState, useReachable, time, transport, care⟩ :=
    accepted_has_checks reachable accepted
  obtain ⟨enrollment, enrollmentReachable, mint, origin⟩ :=
    issued_mandate_has_enrollment reachable localIssue
  exact ⟨useState, enrollment, useReachable, enrollmentReachable, time, transport, care, mint, origin⟩

theorem reserved_key_is_live {s : State} {a prior : Assertion} {atTime : Time}
    (member : .reserved prior atTime ∈ s.history) (issuer : prior.issuer = a.issuer)
    (client : prior.client = a.client) (key : prior.jti = a.jti) (live : s.now < prior.expires) :
    LiveReservation s a :=
  ⟨prior, atTime, member, issuer, client, key, live⟩

theorem issued_assertion_cannot_be_resolved_again {s : State} {t : Token}
    (recorded : .tokenIssued t ∈ s.history) (sameTime : t.issued = s.now) :
    ¬ UnfinishedReservation s t.assertion :=
  fun ready => ready.2.2 t recorded rfl sameTime

theorem closed_credential_cannot_be_polled {s : State} {job : Pending}
    (closed : .closed job.id ∈ s.history) : ¬ PendingReady s job :=
  fun ready => ready.2.1 closed

theorem withdrawal_removes_current_approval (s : State) (r : MandateRequest) :
    (s.record (.approval r.provider r.service none)).currentApproval r = none := by
  simp [State.currentApproval, State.record, List.findSome?]

theorem cancellation_removes_current_availability (s : State) (id : Identifier) :
    (s.record (.availability id none)).currentAvailability id = none := by
  simp [State.currentAvailability, State.record, List.findSome?]

theorem invalid_metadata_discards_snapshot (s : State) (issuer : Issuer) (client : Client) :
    LatestClientSnapshot (s.record (.metadataFailed issuer client .invalidClient)) issuer client = none := by
  simp [LatestClientSnapshot, State.record, List.findSome?]

/-- Discoverability is independent of authorization to issue mandates. -/
theorem withdrawal_prevents_minting {p : Policy} {s : State} {r : MandateRequest}
    {issuer : Issuer} {m : Mandate} :
    ¬ Mint p (s.record (.approval r.provider r.service none)) issuer r m := by
  intro mint
  obtain ⟨a, applies, _⟩ := mint.2.2.2.2.2.1
  have current := applies.1
  rw [withdrawal_removes_current_approval s r] at current
  exact Option.noConfusion current

theorem cancelled_transfer_no_longer_qualifies {p : Policy} {s : State}
    {r : AccessRequest} {availability : Availability} :
    ¬ AvailabilityFor p (s.record (.availability r.transfer none)) r availability := by
  intro qualifies
  have current := qualifies.1
  rw [cancellation_removes_current_availability] at current
  exact Option.noConfusion current

theorem renewal_overlap_unavailable_for_short_lifetime (issued ends : Time)
    (short : ends < issued + 86400) :
    ¬ ∃ publish, issued ≤ publish ∧ publish + 86400 ≤ ends := by
  intro h
  obtain ⟨published, afterIssue, overlap⟩ := h
  exact Nat.not_lt_of_ge (Nat.le_trans (Nat.add_le_add_right afterIssue 86400) overlap) short

inductive OAuthGrant where | jwtBearer | clientCredentials
  deriving DecidableEq

theorem issuance_grant_absent_from_exchange_only_metadata :
    OAuthGrant.clientCredentials ∉ [OAuthGrant.jwtBearer] := by decide

namespace Example

private def policy : Policy where
  clientTLS := fun _ cert => cert = 11 ∨ cert = 22
  serverTLS := fun _ cert => cert = 11 ∨ cert = 22
  providerOfSigner := fun cert => if cert = 101 then some 1 else if cert = 202 then some 2 else none
  serviceOfTLS := fun cert => if cert = 11 then some 111 else if cert = 22 then some 222 else none
  certificateEnds := fun _ => 1000
  signerStatusGood := fun _ cert => cert = 101 ∨ cert = 202
  clientHost := some
  certificateHasDNS := fun cert host => cert = host
  mandateAuthentic := fun _ => True
  assertionAuthentic := fun _ => True
  clientMetadataFetch := fun _ issuer client result =>
    (issuer = 1 ∨ issuer = 2) ∧ result = .document ⟨client, client, true, true⟩ (some 1)
  protectedMetadataFetch := fun _ _ => True
  asEndpoint := fun _ issuer endpoint => endpoint = issuer
  serves := fun _ issuer target => target.provider = issuer ∧ target.resource = issuer
  registeredIssuer := fun _ provider issuer => provider = issuer
  knownIssuer := fun _ _ _ _ => False
  issuerTransportOK := fun _ issuer => issuer = 1 ∨ issuer = 2
  canSign := fun issuer provider signer =>
    (issuer = 1 ∧ provider = 1 ∧ signer = 101) ∨ (issuer = 2 ∧ provider = 2 ∧ signer = 202)
  selfIssuer := fun _ _ => False
  approvalInput := fun _ _ => True
  withdrawalInput := fun _ _ _ => True
  availabilityInput := fun _ id value => value.map Availability.id = some id ∨ value = none
  directoryTarget := fun _ _ target => target = ⟨2, 2⟩
  notificationOK := fun _ n => n.source = ⟨1, 1⟩ ∧ n.recipient = ⟨2, 2⟩
  retrievalOK := fun _ availability operation =>
    availability.patient = 19 ∧ availability.dataset = 20 ∧ operation = .read 7
  tokenVerified := fun _ _ => True
  pendingLifetime := 100
  issuanceTokenLifetime := 100
  accessTokenLifetime := 60
  capMandateAtApproval := true
  capTokenAtMandate := true

private def senderRequest : MandateRequest := ⟨1, 111, [.custodian]⟩
private def receiverRequest : MandateRequest := ⟨2, 222, [.user]⟩
private def senderApproval : Approval := ⟨1, 111, [.custodian], 1, 100⟩
private def receiverApproval : Approval := ⟨2, 222, [.user], 1, 100⟩
private def senderGrant : CredentialGrant := ⟨1, senderRequest, 11, 11, 1, 50⟩
private def receiverGrant : CredentialGrant := ⟨2, receiverRequest, 22, 22, 1, 50⟩
private def senderMandate : Mandate := ⟨101, 1, senderRequest, 101, 1, 1, 100⟩
private def receiverMandate : Mandate := ⟨202, 2, receiverRequest, 202, 1, 1, 100⟩
private def senderMetadata : PeerSnapshot := ⟨⟨1, 11, [1], [senderMandate]⟩, 1, 2⟩
private def receiverMetadata : PeerSnapshot := ⟨⟨2, 22, [2], [receiverMandate]⟩, 1, 2⟩

private def notify (profile : Profile) : Intent := ⟨profile, .notify, 1, ⟨2, 2⟩⟩
private def retrieve (profile : Profile) : Intent := ⟨profile, .retrieve, 2, ⟨1, 1⟩⟩
private def notification (profile : Profile) : Notification := ⟨5, profile, ⟨1, 1⟩, ⟨2, 2⟩, 6⟩
private def availability (profile : Profile) : Availability :=
  ⟨6, profile, ⟨1, 1⟩, 2, 20, 19, 1, 100, [.read 7]⟩
private def notifyAssertion (profile : Profile) : Assertion :=
  ⟨notify profile, 2, 2, 11, 11, senderMandate, 1, 1, 20, [2]⟩
private def pullAssertion (profile : Profile) : Assertion :=
  ⟨retrieve profile, 1, 1, 22, 22, receiverMandate, 2, 1, 20, [1]⟩
private def notifyToken (profile : Profile) : Token := ⟨1, notifyAssertion profile, 1, 40⟩
private def pullToken (profile : Profile) : Token := ⟨2, pullAssertion profile, 1, 40⟩
private def notifyAccess (profile : Profile) : AccessRequest := ⟨notify profile, 11, 6, .notification 5⟩
private def pullAccess (profile : Profile) : AccessRequest := ⟨retrieve profile, 22, 6, .read 7⟩

private def prepared : State :=
  ⟨1, [.mandateIssued receiverMandate, .mandateIssued senderMandate,
    .credentialAuthorized receiverGrant, .credentialAuthorized senderGrant,
    .approval 2 222 (some receiverApproval), .approval 1 111 (some senderApproval),
    .issuerFound 2 222 2, .issuerFound 1 111 1]⟩

private def notified (profile : Profile) : State :=
  ⟨1, [.accepted (notifyAccess profile) (notifyToken profile) 1,
    .notificationAccepted (notification profile), .tokenIssued (notifyToken profile),
    .reserved (notifyAssertion profile) 1, .clientChecked 2 11 11 1,
    .clientFetched ⟨2, ⟨11, 11, true, true⟩, 1, 2⟩,
    .peerChecked (notify profile) 2 2 1, .protectedFetched receiverMetadata] ++ prepared.history⟩

private def accessReady (profile : Profile) : State :=
  ⟨1, [.tokenIssued (pullToken profile), .reserved (pullAssertion profile) 1,
    .clientChecked 1 22 22 1, .clientFetched ⟨1, ⟨22, 22, true, true⟩, 1, 2⟩,
    .peerChecked (retrieve profile) 1 1 1, .protectedFetched senderMetadata,
    .availability 6 (some (availability profile))] ++ (notified profile).history⟩

private def atOne (previous : State) (events : List Event) : State :=
  ⟨1, events ++ previous.history⟩

local macro "pilot_example" : tactic =>
  `(tactic| simp [prepared, notified, accessReady, atOne, State.record, State.currentAvailability, List.findSome?, policy,
    BoundClient, ValidCredentialGrant, ValidMandate, GrantChecks, PeerCheck, PeerRoute, MatchingClientMetadata,
    ValidEnvelope, AcceptTransport, AvailabilityFor, Operation.direction, Direction.clientRole, Direction.peerRole,
    senderRequest, receiverRequest, senderApproval, receiverApproval, senderGrant, receiverGrant,
    senderMandate, receiverMandate, senderMetadata, receiverMetadata, notify, retrieve, notification,
    availability, notifyAssertion, pullAssertion, notifyToken, pullToken, notifyAccess, pullAccess])

private theorem preparedReachable : Reachable policy prepared := by
  have h0 := Reachable.initial (p := policy)
  have h1 := Reachable.advance h0 (Step.tick 1 (by pilot_example))
  have h2 := Reachable.advance h1 (Step.discover 1 111 1 (Or.inl rfl))
  have h3 := Reachable.advance h2 (Step.discover 2 222 2 (Or.inl rfl))
  have h4 := Reachable.advance h3 (Step.approve senderApproval trivial (by pilot_example))
  have h5 := Reachable.advance h4 (Step.approve receiverApproval trivial (by pilot_example))
  have h6 := Reachable.advance h5 (Step.credentialGrant senderGrant (by pilot_example)
    (by pilot_example) (by pilot_example) (by pilot_example) ⟨101, Or.inl ⟨rfl, rfl, rfl⟩⟩
    (by pilot_example) rfl (by pilot_example) (by pilot_example))
  have h7 := Reachable.advance h6 (Step.credentialGrant receiverGrant (by pilot_example)
    (by pilot_example) (by pilot_example) (by pilot_example) ⟨202, Or.inr ⟨rfl, rfl, rfl⟩⟩
    (by pilot_example) rfl (by pilot_example) (by pilot_example))
  have h8 := Reachable.advance h7 (Step.issueImmediate senderGrant senderMandate (by pilot_example) (by
    refine ⟨rfl, rfl, Or.inl ⟨rfl, rfl, rfl⟩, rfl, by pilot_example, ⟨senderApproval, ?_, by pilot_example⟩, ?_⟩
    · refine ⟨rfl, rfl, rfl, by pilot_example, by pilot_example, by pilot_example, ?_⟩
      intro role member
      exact member
    · simp [State.record]))
  have h9 := Reachable.advance h8 (Step.issueImmediate receiverGrant receiverMandate (by pilot_example) (by
    refine ⟨rfl, rfl, Or.inr ⟨rfl, rfl, rfl⟩, rfl, by pilot_example, ⟨receiverApproval, ?_, by pilot_example⟩, ?_⟩
    · refine ⟨rfl, rfl, rfl, by pilot_example, by pilot_example, by pilot_example, ?_⟩
      intro role member
      exact member
    · simp [State.record, senderMandate, receiverMandate]))
  exact h9

private theorem step10 : Reachable policy (atOne prepared
      [.protectedFetched receiverMetadata]) := by
  exact Reachable.advance preparedReachable
    (Step.readProtected receiverMetadata trivial (by pilot_example) rfl (by pilot_example) (by pilot_example))

private theorem step11 (profile : Profile) : Reachable policy (atOne prepared
      [.peerChecked (notify profile) 2 2 1, .protectedFetched receiverMetadata]) := by
  exact Reachable.advance step10
    (Step.verifyPeer (notify profile) 2 2 receiverMetadata receiverMandate (by pilot_example))

private theorem step12 (profile : Profile) : Reachable policy (atOne prepared
      [.clientChecked 2 11 11 1, .clientFetched ⟨2, ⟨11, 11, true, true⟩, 1, 2⟩, .peerChecked (notify profile) 2 2 1, .protectedFetched receiverMetadata]) := by
  exact Reachable.advance (step11 profile)
    (Step.fetchClient 2 11 11 ⟨11, 11, true, true⟩ (some 1) (by pilot_example) (by pilot_example) (by pilot_example))

private theorem step13 (profile : Profile) : Reachable policy (atOne prepared
      [.reserved (notifyAssertion profile) 1, .clientChecked 2 11 11 1, .clientFetched ⟨2, ⟨11, 11, true, true⟩, 1, 2⟩, .peerChecked (notify profile) 2 2 1, .protectedFetched receiverMetadata]) := by
  exact Reachable.advance (step12 profile) (Step.reserve (notifyAssertion profile) (by pilot_example) (by simp [atOne, LiveReservation, prepared, State.record]))

private theorem notifyGrantChecks (profile : Profile) (state : State) (time : state.now = 1) :
    GrantChecks policy state (notifyAssertion profile) := by
  refine ⟨?_, rfl, rfl, by change Role.custodian ∈ [Role.custodian]; decide, by change 2 ∈ [2]; decide, ?_⟩
  · rw [time]
    change ValidMandate policy 1 senderMandate
    exact ⟨trivial, rfl, Or.inl rfl, by decide, by decide, by decide, by decide, by decide⟩
  · intro resource member
    have eq : resource = 2 := List.mem_singleton.mp member
    exact ⟨rfl, eq⟩

private theorem pullGrantChecks (profile : Profile) (state : State) (time : state.now = 1) :
    GrantChecks policy state (pullAssertion profile) := by
  refine ⟨?_, rfl, rfl, by change Role.user ∈ [Role.user]; decide, by change 1 ∈ [1]; decide, ?_⟩
  · rw [time]
    change ValidMandate policy 1 receiverMandate
    exact ⟨trivial, rfl, Or.inr rfl, by decide, by decide, by decide, by decide, by decide⟩
  · intro resource member
    have eq : resource = 1 := List.mem_singleton.mp member
    exact ⟨rfl, eq⟩

private theorem recordSenderMetadata (state : State) (prior : Reachable policy state)
    (time : state.now = 1) : Reachable policy (state.record (.protectedFetched senderMetadata)) := by
  apply Reachable.advance prior
  refine Step.readProtected senderMetadata trivial (Or.inl rfl) time.symm ?_ ?_
  · rw [time]
    decide
  · rw [time]
    decide

private theorem step14 (profile : Profile) : Reachable policy (atOne prepared
      [.tokenIssued (notifyToken profile), .reserved (notifyAssertion profile) 1, .clientChecked 2 11 11 1, .clientFetched ⟨2, ⟨11, 11, true, true⟩, 1, 2⟩, .peerChecked (notify profile) 2 2 1, .protectedFetched receiverMetadata]) := by
  exact Reachable.advance (step13 profile) (Step.issueToken (notifyToken profile)
    (by pilot_example)
    (by simp [atOne, UnfinishedReservation, prepared, State.record, notifyToken, notifyAssertion])
    (notifyGrantChecks profile _ rfl)
    rfl (by change 1 < 40; decide) (by change 40 ≤ 61; decide)
    (fun _ => by change 40 ≤ 100; decide) (by simp [atOne, prepared, State.record]))

private theorem notifiedReachable (profile : Profile) : Reachable policy (notified profile) := by
  exact Reachable.advance (step14 profile) (Step.acceptNotification (notifyAccess profile)
    (notifyToken profile) (notification profile)
    (by pilot_example) rfl rfl rfl rfl rfl rfl (by pilot_example))

private theorem step16 (profile : Profile) : Reachable policy (atOne (notified profile)
      [.availability 6 (some (availability profile))]) := by
  exact Reachable.advance (notifiedReachable profile) (Step.publishAvailability 6 (some (availability profile))
    (by pilot_example))

private theorem step17 (profile : Profile) : Reachable policy (atOne (notified profile)
      [.protectedFetched senderMetadata, .availability 6 (some (availability profile))]) := by
  exact recordSenderMetadata _ (step16 profile) rfl

private theorem step18 (profile : Profile) : Reachable policy (atOne (notified profile)
      [.peerChecked (retrieve profile) 1 1 1, .protectedFetched senderMetadata, .availability 6 (some (availability profile))]) := by
  exact Reachable.advance (step17 profile)
    (Step.verifyPeer (retrieve profile) 1 1 senderMetadata senderMandate (by
      refine ⟨⟨notification profile, ?_, rfl, rfl, rfl⟩, ?_⟩
      · simp [atOne, notified, prepared, State.record]
      · pilot_example))

private theorem step19 (profile : Profile) : Reachable policy (atOne (notified profile)
      [.clientChecked 1 22 22 1, .clientFetched ⟨1, ⟨22, 22, true, true⟩, 1, 2⟩, .peerChecked (retrieve profile) 1 1 1, .protectedFetched senderMetadata, .availability 6 (some (availability profile))]) := by
  exact Reachable.advance (step18 profile)
    (Step.fetchClient 1 22 22 ⟨22, 22, true, true⟩ (some 1) (by pilot_example) (by pilot_example) (by pilot_example))

private theorem step20 (profile : Profile) : Reachable policy (atOne (notified profile)
      [.reserved (pullAssertion profile) 1, .clientChecked 1 22 22 1, .clientFetched ⟨1, ⟨22, 22, true, true⟩, 1, 2⟩, .peerChecked (retrieve profile) 1 1 1, .protectedFetched senderMetadata, .availability 6 (some (availability profile))]) := by
  exact Reachable.advance (step19 profile) (Step.reserve (pullAssertion profile) (by pilot_example)
    (by simp [atOne, LiveReservation, notified, prepared, State.record, notifyAssertion, pullAssertion]))

private theorem accessReadyReachable (profile : Profile) : Reachable policy (atOne (notified profile)
      [.tokenIssued (pullToken profile), .reserved (pullAssertion profile) 1, .clientChecked 1 22 22 1, .clientFetched ⟨1, ⟨22, 22, true, true⟩, 1, 2⟩, .peerChecked (retrieve profile) 1 1 1, .protectedFetched senderMetadata, .availability 6 (some (availability profile))]) := by
  exact Reachable.advance (step20 profile) (Step.issueToken (pullToken profile)
    (by pilot_example)
    (by simp [atOne, UnfinishedReservation, notified, prepared, State.record, notifyToken, pullToken, pullAssertion, notifyAssertion])
    (pullGrantChecks profile _ rfl)
    rfl (by change 1 < 40; decide) (by change 40 ≤ 61; decide)
    (fun _ => by change 40 ≤ 100; decide)
    (by simp [atOne, notified, prepared, State.record, notifyToken, pullToken]))

-- Both sides obtain a mandate, then notify and retrieve for the selected profile.
theorem notified_pull_is_reachable (profile : Profile) :
    ∃ s, Reachable policy s ∧
      .accepted (notifyAccess profile) (notifyToken profile) 1 ∈ s.history ∧
      .accepted (pullAccess profile) (pullToken profile) 1 ∈ s.history := by
  have h22 := Reachable.advance (accessReadyReachable profile)
    (Step.acceptRetrieval (pullAccess profile) (pullToken profile) (availability profile)
      (by pilot_example) rfl (by pilot_example))
  exact ⟨_, h22, by simp [atOne, notified, State.record], by simp [atOne, State.record]⟩

end Example
end GFPilot
