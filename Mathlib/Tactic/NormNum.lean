/-
Copyright (c) 2021 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
import Lean.Elab.Tactic.Basic
import Mathlib.Algebra.Ring.Basic

namespace Lean
namespace Meta

def mkOfNatLit (u : Level) (α sα n : Expr) : Expr :=
  let inst := mkApp3 (mkConst ``Numeric.OfNat [u]) α n sα
  mkApp3 (mkConst ``OfNat.ofNat [u]) α n inst

namespace NormNum

theorem ofNat_add {α} [Semiring α] : (a b : α) → (a' b' c : Nat) →
  a = OfNat.ofNat a' → b = OfNat.ofNat b' → a' + b' = c → a + b = OfNat.ofNat c
| _, _, _, _, _, rfl, rfl, rfl => (Semiring.ofNat_add _ _).symm

theorem ofNat_mul {α} [Semiring α] : (a b : α) → (a' b' c : Nat) →
  a = OfNat.ofNat a' → b = OfNat.ofNat b' → a' * b' = c → a * b = OfNat.ofNat c
| _, _, _, _, _, rfl, rfl, rfl => (Semiring.ofNat_mul _ _).symm


partial def eval : Expr → MetaM (Expr × Expr)
| e => e.withApp fun f args => do
  println! "X1"
  if f.isConstOf ``HAdd.hAdd then
    evalB ``NormNum.ofNat_add (·+·) args
  else if f.isConstOf ``HMul.hMul then
    evalB ``NormNum.ofNat_mul (·*·) args
  else if f.isConstOf ``OfNat.ofNat then
    let #[α,ln,_] ← args | throwError "fail"
    let some n ← ln.natLit? | throwError "fail"
    if n = 0 then
      let Level.succ u _ ← getLevel α | throwError "fail"
      let nα ← synthInstance (mkApp (mkConst ``Numeric [u]) α)
      let sα ← synthInstance (mkApp (mkConst ``Semiring [u]) α)
      let e ← mkOfNatLit u α nα (mkNatLit 0)
      let p ← mkEqSymm (mkApp2 (mkConst ``Semiring.ofNat_zero [u]) α sα)
      return (e,p)
    else if n = 1 then
      let Level.succ u _ ← getLevel α | throwError "fail"
      let nα ← synthInstance (mkApp (mkConst ``Numeric [u]) α)
      let sα ← synthInstance (mkApp (mkConst ``Semiring [u]) α)
      let e ← mkOfNatLit u α nα (mkNatLit 1)
      let p ← mkEqSymm (mkApp2 (mkConst ``Semiring.ofNat_one [u]) α sα)
      return (e,p)
    else pure (e, ← mkEqRefl e)
  else throwError "fail"
where
  evalB (name : Name) (f : Nat → Nat → Nat)
    (args : Array Expr) : MetaM (Expr × Expr) := do
    if let #[_, _, α, _, a, b] ← args then
      let Level.succ u _ ← getLevel α | throwError "fail"
      let nα ← synthInstance (mkApp (mkConst ``Numeric [u]) α)
      let sα ← synthInstance (mkApp (mkConst ``Semiring [u]) α)
      let (a', pa) ← eval a
      let (b', pb) ← eval b
      let la := Expr.getRevArg! a' 1
      let some na ← la.natLit? | throwError "fail"
      let lb := Expr.getRevArg! b' 1
      let some nb ← lb.natLit? | throwError "fail"
      let lc := mkNatLit (f na nb)
      let c := mkOfNatLit u α nα lc
      pure (c, mkApp10 (mkConst name [u]) α sα a b la lb lc pa pb (← mkEqRefl lc))
    else throwError "fail"

end NormNum
end Meta

syntax (name := Parser.Tactic.normNum) "normNum" : tactic

open Meta Elab Tactic

@[tactic normNum] def Tactic.evalNormNum : Tactic := fun stx =>
  liftMetaTactic fun g => do
    let some (α, lhs, rhs) ← matchEq? (← getMVarType g) | throwError "fail"
    let (lhs2, p) ← NormNum.eval lhs
    unless ← isDefEq lhs2 rhs do throwError "fail"
    assignExprMVar g p
    pure []

end Lean

-- set_option pp.all true
variable (α) [Semiring α]
example : (2 + 2 + 2 + 1 : α) = 7 := by normNum
example : (0 + (2 + 3) + 7 : α) = 12 := by normNum
example : (70 * (33 + 2) : α) = 2450 := by normNum
