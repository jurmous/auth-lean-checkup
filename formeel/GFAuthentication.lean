import Std

set_option autoImplicit false

namespace GFAuthentication

/- Identiteiten en URL's zijn getypeerde, genormaliseerde waarden. De modelgrens
   ligt na parsing, TLS-, PKI-, JOSE- en metadata-validatie. -/
inductive Provider where | sender | receiver | other
  deriving DecidableEq
inductive ResourceBase where | first | second
  deriving DecidableEq
inductive Purpose where | treat | emergency | patientRequest | research | administration
  deriving DecidableEq
inductive Role where | user | custodian
  deriving DecidableEq
inductive Direction where | notify | retrieve
  deriving DecidableEq

def Direction.clientRole : Direction → Role
  | .notify => .custodian
  | .retrieve => .user

def Direction.peerRole : Direction → Role
  | .notify => .user
  | .retrieve => .custodian

structure Code where
  purpose : Purpose
  role : Role
  deriving DecidableEq

structure Target where
  provider : Provider
  base : ResourceBase
  deriving DecidableEq

structure Mandate where
  subject : Provider
  signer : Provider
  delegate : Nat
  codes : List Code
  starts : Nat
  expires : Nat
  deriving DecidableEq

structure Assertion where
  subject : Provider
  client : Nat
  signerCertificate : Nat
  audience : Nat
  purpose : Purpose
  targetProvider : Provider
  locations : List ResourceBase
  issuedAt : Nat
  expires : Nat
  deriving DecidableEq

structure Context where
  now : Nat
  authorizationServer : Nat
  client : Nat
  certificate : Nat
  certificateDelegate : Nat
  certificateOK : Prop
  clientMetadataOK : Prop
  assertionSignatureAndTypeOK : Prop
  mandateSignatureAndTypeOK : Prop
  assertionUnused : Prop
  served : Target → Prop

def ValidMandate (now : Nat) (m : Mandate) : Prop :=
  m.signer = m.subject ∧ m.starts ≤ now ∧ now < m.expires ∧
    m.expires ≤ m.starts + 92 * 24 * 60 * 60

def CommonChecks (c : Context) (a : Assertion) (m : Mandate) : Prop :=
  c.certificateOK ∧ c.clientMetadataOK ∧ c.assertionSignatureAndTypeOK ∧
  c.mandateSignatureAndTypeOK ∧ c.assertionUnused ∧
  a.client = c.client ∧ a.signerCertificate = c.certificate ∧
  a.audience = c.authorizationServer ∧
  a.issuedAt ≤ c.now + 60 ∧ c.now < a.expires ∧ a.expires ≤ a.issuedAt + 300 ∧
  ValidMandate c.now m ∧ a.subject = m.subject ∧ m.delegate = c.certificateDelegate

theorem assertion_remaining_bound (c : Context) (a : Assertion) (m : Mandate)
    (h : CommonChecks c a m) : a.expires ≤ c.now + 360 := by
  rcases h with ⟨_, _, _, _, _, _, _, _, hi, _, he, _⟩
  omega

def PeerVerified (now : Nat) (expected : Provider) (p : Purpose) (d : Direction)
    (peerTLSDelegate chosenAS : Nat) (listed : List Nat) (m : Mandate) : Prop :=
  ValidMandate now m ∧ m.subject = expected ∧ m.delegate = peerTLSDelegate ∧
    Code.mk p d.peerRole ∈ m.codes ∧ chosenAS ∈ listed

theorem client_and_peer_roles_differ (d : Direction) : d.clientRole ≠ d.peerRole := by
  cases d <;> decide

def ExactRole (a : Assertion) (m : Mandate) (direction : Direction) : Prop :=
  Code.mk a.purpose direction.clientRole ∈ m.codes

def RoleAllowedByUseCase (a : Assertion) (m : Mandate) (allowsNotification : Prop) : Prop :=
  ExactRole a m .retrieve ∨ (allowsNotification ∧ ExactRole a m .notify)

def ExactTargets (c : Context) (a : Assertion) : Prop :=
  a.locations ≠ [] ∧ ∀ base ∈ a.locations, c.served ⟨a.targetProvider, base⟩

def SeparatelyKnownTargets (c : Context) (a : Assertion) : Prop :=
  (∃ base, c.served ⟨a.targetProvider, base⟩) ∧
    ∀ base ∈ a.locations, ∃ provider, c.served ⟨provider, base⟩

def StrictPilotGrant (c : Context) (a : Assertion) (m : Mandate) (d : Direction) : Prop :=
  CommonChecks c a m ∧ a.purpose = .treat ∧ ExactRole a m d ∧ ExactTargets c a

structure Token where
  subject : Provider
  certificate : Nat
  expires : Nat
  purpose : Purpose
  targetProvider : Provider
  locations : List ResourceBase
  deriving DecidableEq

def issue (c : Context) (a : Assertion) (m : Mandate) (expires : Nat) : Token :=
  ⟨m.subject, c.certificate, expires, a.purpose, a.targetProvider, a.locations⟩

def TokenTimeAndCert (t : Token) (now cert : Nat) : Prop :=
  now < t.expires ∧ cert = t.certificate

def TokenTargets (t : Token) (target : Target) : Prop :=
  target.provider = t.targetProvider ∧ target.base ∈ t.locations

theorem authorization_carries_subject_and_certificate
    (c : Context) (a : Assertion) (m : Mandate) (d : Direction) (expiry : Nat)
    (h : StrictPilotGrant c a m d) :
    (issue c a m expiry).subject = a.subject ∧
      (issue c a m expiry).certificate = a.signerCertificate := by
  rcases h.1 with ⟨_, _, _, _, _, _, hc, _, _, _, _, _, hs, _⟩
  exact ⟨hs.symm, hc.symm⟩

theorem verified_target_is_served
    (c : Context) (a : Assertion) (m : Mandate) (d : Direction) (expiry : Nat)
    (target : Target) (grant : StrictPilotGrant c a m d)
    (accept : TokenTargets (issue c a m expiry) target) : c.served target := by
  rcases target with ⟨provider, base⟩
  rcases accept with ⟨hp, hb⟩
  change provider = a.targetProvider at hp
  subst provider
  exact grant.2.2.2.2 base hb

-- Existentiële modellen van de regeltekst, zonder protocolverkeer of implementatiedetails.
private def assertion : Assertion :=
  ⟨.receiver, 1, 2, 3, .treat, .sender, [.first], 10, 20⟩

private def mandate (codes : List Code) : Mandate :=
  ⟨.receiver, .receiver, 4, codes, 0, 30⟩

private def context : Context :=
  ⟨10, 3, 1, 2, 4, True, True, True, True, True, fun _ => True⟩

theorem pilot_grant_has_valid_instances :
    ∃ c a m, StrictPilotGrant c a m .retrieve := by
  refine ⟨context, assertion, mandate [⟨.treat, .user⟩], ?_⟩
  simp [StrictPilotGrant, CommonChecks, ExactRole, ExactTargets, ValidMandate,
    context, assertion, mandate, Direction.clientRole]

theorem role_disjunction_does_not_determine_direction :
    ∃ a m, RoleAllowedByUseCase a m True ∧ ¬ ExactRole a m .notify := by
  refine ⟨assertion, mandate [⟨.treat, .user⟩], ?_⟩
  simp [RoleAllowedByUseCase, ExactRole, assertion, mandate, Direction.clientRole]

theorem separate_membership_does_not_establish_pairing :
    ∃ c a, SeparatelyKnownTargets c a ∧ ¬ ExactTargets c a := by
  let served (target : Target) :=
    target = Target.mk Provider.sender ResourceBase.second ∨
      target = Target.mk Provider.other ResourceBase.first
  let c := { context with served := served }
  refine ⟨c, assertion, ?_, ?_⟩
  · constructor
    · exact ⟨.second, Or.inl rfl⟩
    intro base hb
    have e : base = .first := by simpa [assertion] using hb
    subst base
    exact ⟨.other, Or.inr rfl⟩
  · intro h
    have pair := h.2 .first (by simp [assertion])
    simp [c, served, assertion] at pair

theorem time_and_certificate_do_not_entail_target :
    ∃ c a m expiry target,
      StrictPilotGrant c a m .retrieve ∧
        TokenTimeAndCert (issue c a m expiry) 11 2 ∧
        ¬ TokenTargets (issue c a m expiry) target := by
  refine ⟨context, assertion, mandate [⟨.treat, .user⟩], 20, ⟨.other, .first⟩, ?_⟩
  simp [StrictPilotGrant, CommonChecks, ExactRole, ExactTargets, ValidMandate,
    TokenTimeAndCert, TokenTargets, issue, context, assertion, mandate, Direction.clientRole]

structure Transfer where
  recipient : Provider
  resourceIds : List Nat
  ends : Nat

def TaskConditions (t : Token) (transfer : Transfer) (resourceId : Nat) : Prop :=
  transfer.recipient = t.subject ∧ resourceId ∈ transfer.resourceIds

def ActiveTransfer (t : Token) (transfer : Transfer) (resourceId now : Nat) : Prop :=
  TaskConditions t transfer resourceId ∧ now < transfer.ends

theorem task_membership_does_not_entail_active_transfer :
    ∃ t transfer resourceId now, TaskConditions t transfer resourceId ∧
        ¬ ActiveTransfer t transfer resourceId now := by
  refine ⟨issue context assertion (mandate [⟨.treat, .user⟩]) 20,
    ⟨.receiver, [1], 12⟩, 1, 12, ?_⟩
  simp [ActiveTransfer, TaskConditions, issue, context, assertion, mandate]

def ValidApprovalAtIssuance (issuedAt approvalEnds : Nat) (m : Mandate) : Prop :=
  issuedAt < approvalEnds ∧ ValidMandate issuedAt m

theorem approval_at_issuance_does_not_bound_mandate_expiry :
    ∃ issuedAt approvalEnds m,
      ValidApprovalAtIssuance issuedAt approvalEnds m ∧ approvalEnds < m.expires := by
  refine ⟨10, 11, mandate [⟨.treat, .user⟩], ?_⟩
  simp [ValidApprovalAtIssuance, ValidMandate, mandate]

theorem token_validity_does_not_end_with_mandate :
    ∃ c a m expiry now,
      StrictPilotGrant c a m .retrieve ∧
        TokenTimeAndCert (issue c a m expiry) now c.certificate ∧ m.expires ≤ now := by
  refine ⟨context, assertion, mandate [⟨.treat, .user⟩], 40, 30, ?_⟩
  simp [StrictPilotGrant, CommonChecks, ExactRole, ExactTargets, ValidMandate,
    TokenTimeAndCert, issue, context, assertion, mandate, Direction.clientRole]

theorem bounded_lifetimes_compose (approvalEnds mandateEnds tokenEnds now : Nat)
    (mandateBound : mandateEnds ≤ approvalEnds) (tokenBound : tokenEnds ≤ mandateEnds)
    (tokenValid : now < tokenEnds) : now < mandateEnds ∧ now < approvalEnds := by
  omega

-- De reserveeroperatie abstraheert van de opslag en wordt als één stap toegepast.
def Reserve (used : List Nat) (jti : Nat) (next : List Nat) : Prop :=
  jti ∉ used ∧ next = jti :: used

theorem no_second_reservation (used next after : List Nat) (jti : Nat)
    (first : Reserve used jti next) : ¬ Reserve next jti after := by
  obtain ⟨_, rfl⟩ := first
  simp [Reserve]

namespace SubmittedRules

-- Tijdcontroles uit AS-stap 4, zonder invoer over cryptografie of transport.
def AssertionTime (now iat exp : Nat) : Prop :=
  iat ≤ now + 60 ∧ now < exp ∧ exp ≤ iat + 300

theorem assertion_expiry_bound_is_sharp (now : Nat) :
    (∀ iat exp, AssertionTime now iat exp → exp ≤ now + 360) ∧
      (∃ iat, AssertionTime now iat (now + 360)) := by
  constructor
  · intro iat exp rules
    obtain ⟨futureLimit, _, lifetime⟩ := rules
    omega
  · refine ⟨now + 60, ?_⟩
    unfold AssertionTime
    omega

-- De Java- en .NET-validators verschillen op deze extra ordeningscontrole.
theorem assertion_time_limits_do_not_imply_date_order :
    ∃ now iat exp, AssertionTime now iat exp ∧ ¬ iat ≤ exp := by
  exact ⟨0, 2, 1, ⟨by decide, by decide, by decide⟩, by decide⟩

theorem equality_requires_an_explicit_rule :
    ∃ now iat exp, AssertionTime now iat exp ∧ iat ≤ exp ∧ ¬ iat < exp := by
  exact ⟨0, 1, 1, ⟨by decide, by decide, by decide⟩, by decide, by decide⟩

-- GF-AUTN-6 telt vanaf ophalen; de normale versheidsduur wordt niet opgeteld.
theorem caching_limit_is_measured_from_fetch (fetched now : Nat)
    (atLimit : fetched + 86400 ≤ now) : ¬ now < fetched + 86400 :=
  Nat.not_lt_of_ge atLimit

theorem cache_after_freshness_is_a_different_limit (fetched : Nat) :
    ∃ now, now < (fetched + 3600) + 86400 ∧ ¬ now < fetched + 86400 := by
  refine ⟨fetched + 86400, ?_, Nat.lt_irrefl _⟩
  omega

structure AssertionLogKey where
  issuer : Nat
  client : Nat
  jti : Nat
  deriving DecidableEq

theorem jti_alone_does_not_identify_a_log_record :
    ∃ first second : AssertionLogKey, first.jti = second.jti ∧ first ≠ second := by
  exact ⟨⟨0, 0, 1⟩, ⟨0, 1, 1⟩, rfl, by decide⟩

end SubmittedRules

end GFAuthentication
