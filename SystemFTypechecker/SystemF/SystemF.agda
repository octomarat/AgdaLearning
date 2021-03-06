module SystemF where

open import Data.Nat
open import Data.List hiding (all ; [_])
open import Data.Maybe
open import Relation.Binary.PropositionalEquality hiding ([_])
open import Relation.Nullary

-- Variable with number as name --
data Var : Set where
  v : ℕ → Var

-- Type variables --
-- type variable with number as name
data TVar : Set where
  tv : ℕ → TVar

-- type variable equality check
eqTVar : (a : TVar) → (b : TVar) → Maybe (a ≡ b)
eqTVar (tv n) (tv m)  with compare n m
eqTVar (tv n) (tv .n) | equal .n = just refl
...                   | _  = nothing

-- Types --
-- type construction rules
infixr 30 _⇒_
data Type : Set where
  NAT : Type
  _⇒_ : Type → Type → Type
  TVAR : TVar → Type
  ALL_▴_ : TVar → Type → Type

-- type equality check
_=?=_ : (T S : Type) -> Maybe (T ≡ S)

NAT =?= NAT = just refl
NAT =?= _ = nothing

T1 ⇒ S1 =?= T2 ⇒ S2 with T1 =?= T2 | S1 =?= S2
T ⇒ S =?= .T ⇒ .S   | just refl | just refl = just refl
...                 | _ | _ = nothing
T1 ⇒ T2 =?= _ = nothing

TVAR X =?= TVAR Y with eqTVar X Y
TVAR X =?= TVAR .X | just refl = just refl
...                | _  = nothing
TVAR _ =?= _ = nothing

ALL X ▴ T =?= ALL Y ▴ S with eqTVar X Y | T =?= S
ALL X ▴ T =?= ALL .X ▴ .T | just refl | just refl = just refl
ALL X ▴ T =?= ALL Y ▴ S | _ | _ = nothing
ALL X ▴ T =?= _ = nothing

-- Untyped (but annotated) term construction rules --
infixl 50 lam_:-_▴_ tlam_▴_
infixl 40 _$_ _[_]
data RawTerm : Set where
  var : Var → RawTerm
  lam_:-_▴_ : Var → Type → RawTerm → RawTerm
  _$_ : RawTerm → RawTerm → RawTerm
  tlam_▴_ : TVar → RawTerm → RawTerm
  _[_] : RawTerm → Type → RawTerm

-- Contexts --
-- context binding
infix 50 _:-_
data Binding : Set where
  _:-_ : Var → Type → Binding
  tb : TVar → Binding 

getName : Binding → ℕ
getName (v n :- _) = n
getName (tb (tv n)) = n

-- freshness proposition
data IsFresh : Binding → List Binding → Set where
  ∅-fresh : ∀ {b} → IsFresh b []
  app-fresh : ∀ {a b bs} → ¬ (getName a ≡ getName b) → IsFresh a bs → IsFresh a (b ∷ bs)

-- context construction rules
data Ctxt : List Binding → Set where
  ∅ : Ctxt []
  _,_[_] : ∀ {bs} → (c : Ctxt bs) → (t : Binding) → IsFresh t bs → Ctxt (t ∷ bs)

-- freshness check
isFresh : ∀ {bs} → (b : Binding) → (Γ : Ctxt bs) → Maybe (IsFresh b bs)
isFresh {[]} _ _ = just ∅-fresh
isFresh a (Δ , b [ _ ]) with getName a ≟ getName b | isFresh a Δ
... | no prfNeq | just prfFresh = just (app-fresh prfNeq prfFresh)
... | _ | _ = nothing

-- Utils for typing rules --
-- variable belongs to bindings list proposition
data _∈_ (t : Var) : List Binding → Set where
  ∈-hd : ∀ {bs T} → t ∈ (t :- T ∷ bs)
  ∈-tl : ∀ {b bs} → t ∈ bs → t ∈ (b ∷ bs)

-- check if variable belongs to bindings list
lookup : (bs : List Binding) → (t : Var) → Maybe (t ∈ bs)
lookup [] _ = nothing
lookup ((v n :- T) ∷ bs) (v m)   with compare n m
lookup ((v .n :- T) ∷ bs) (v .n) | equal n = just ∈-hd
lookup ((v n :- T) ∷ bs) (v m)   | _ with lookup bs (v m)
lookup ((v n :- T) ∷ bs) (v m)   | _ | just p = just (∈-tl p)
lookup ((v n :- T) ∷ bs) (v m)   | _ | _ = nothing
lookup (b ∷ bs) vv with lookup bs vv
... | just p = just (∈-tl p)
... | _ = nothing

varType : ∀ {t bs} → t ∈ bs → Type
varType (∈-hd {_} {T}) = T
varType (∈-tl prop) = varType prop

-- substitution in type
infix 50 [_↦_]_
[_↦_]_ : TVar → Type → Type → Type
[ X ↦ S ] NAT = NAT
[ X ↦ S ] (A ⇒ B) = [ X ↦ S ] A ⇒ [ X ↦ S ] B
[ X ↦ S ] TVAR Y  with eqTVar X Y
[ X ↦ S ] TVAR .X | just refl = S
...               | _ = TVAR Y
[ X ↦ S ] (ALL Y ▴ T) = ALL Y ▴ [ X ↦ S ] T

-- Typing rules --
data _⊢_:-_ {bs : List Binding} (Γ : Ctxt bs) : RawTerm → Type → Set where
  T-Var : ∀ {v} → (prop : v ∈ bs) → 
          Γ ⊢ (var v) :- (varType prop)
  T-Abs : ∀ {t₁ t₂ T₁ T₂ fp} → (Γ , (t₁ :- T₁) [ fp ] ⊢ t₂ :- T₂) → 
          Γ ⊢ (lam t₁ :- T₁ ▴ t₂) :- (T₁ ⇒ T₂)
  T-App : ∀ {t₁ t₂ T₁ T₂} → (Γ ⊢ t₁ :- T₁ ⇒ T₂) → (Γ ⊢ t₂ :- T₁) → 
          Γ ⊢ (t₁ $ t₂) :- T₂
  T-TAbs : ∀ {t T X fp} → (Γ , (tb X) [ fp ] ⊢ t :- T) → 
           Γ ⊢ tlam X ▴ t :- (ALL X ▴ T)
  T-TApp : ∀ {t X T S} → Γ ⊢ t :- (ALL X ▴ T) → 
           Γ ⊢ t [ S ] :- [ X ↦ S ] T

-- Type inference --
-- type inference result
data TypeInfo {bs} (Γ : Ctxt bs) : RawTerm → Set where
  typed : ∀ {t T} → Γ ⊢ t :- T → TypeInfo Γ t
  bad : {rt : RawTerm} -> TypeInfo Γ rt

-- performs type inference
infer : ∀ {bs} → (Γ : Ctxt bs) → (rt : RawTerm) → TypeInfo Γ rt

infer {bs} Γ (var x) with lookup bs x
... | just prf = typed (T-Var prf)
... | _ = bad

infer Γ (lam x :- T ▴ rt) with isFresh (x :- T) Γ
...                       | nothing = bad
infer Γ (lam x :- T ▴ rt) | just fp with infer (Γ , (x :- T) [ fp ]) rt
...                                 | bad = bad
infer Γ (lam x :- T ▴ rt) | just fp | typed prop = typed (T-Abs prop)

infer Γ (t $ s) with infer Γ t
...             | bad = bad
infer Γ (t $ s) | typed {.t} {T ⇒ S} prf-t with infer Γ s
...                                        | bad = bad
infer Γ (t $ s) | typed {.t} {T ⇒ S} prf-t | typed {.s} {T'} prf-s with T =?= T'
infer Γ (t $ s) | typed {.t} {T ⇒ S} prf-t | typed {.s} {.T} prf-s | just refl = typed (T-App prf-t prf-s)
...                                                                | _ = bad
infer Γ (t $ s) | _ = bad

infer Γ (tlam X ▴ rt) with isFresh (tb X) Γ 
...                   | nothing = bad
infer Γ (tlam X ▴ rt) | just fp with infer (Γ , (tb X) [ fp ]) rt
...                             | bad = bad
infer Γ (tlam X ▴ rt) | just fp | typed prop = typed (T-TAbs prop)

infer Γ (rt [ S ]) with infer Γ rt
infer Γ (rt [ S ]) | bad = bad
infer Γ (rt [ S ]) | typed {.rt} {ALL X ▴ T} prf = typed (T-TApp prf)
infer Γ (rt [ S ]) | _  = bad
