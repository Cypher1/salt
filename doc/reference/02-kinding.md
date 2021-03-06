
# Kinding

## Judgment Forms

```
1) Γ ⊢ T  :: K
2) Γ ⊢ Ts :* Ks
3) Γ ⊢ Ts :< K
```

1. In environment `Γ` type `T` has kind `K`.
2. In environment `Γ` types `Ts` have kinds `Ks`.
3. In environment `Γ` types `Ts` all have the same kind `K`.

## Rules

```
                  { Γ ⊢ Tsᵢ :: Ksᵢ } ^ (i ← [1 .. n])
(k-many)        ---------------------------------------
                    Γ ⊢ Tsⁿ :* Ksⁿ


                  { Γ ⊢ Tsᵢ :: K } ^ (i ← [1.. n])
(k-gets)        ---------------------------------------
                    Γ ⊢ Tsⁿ :< K

```

```
                      a:K ∈ Γ
(k-var)           -------------------
                    Γ ⊢ tvar a :: K


                     c has kind K
(k-con)           -------------------
                    Γ ⊢ tcon c :: K


                     p has kind K
(k-prm)           -------------------
                    Γ ⊢ tprm p :: K


                  Γ ⊢ T₁ :: tarr Ks₂ K₂    Γ ⊢ Ts₂ :* Ks₂
(k-app)         -----------------------------------------
                    Γ ⊢ tapp T₁ Ts₂ :: K₂


                  Γ ⊢ Ts₁ :< tdat   Γ ⊢ Ts₂ :< tdat
(k-fun)         ---------------------------------------
                    Γ ⊢ tfun Ts₁ Ts₂ :: tdat


                  { Γ ⊢ Tsᵢ :< tdat } ^ (i ← [1 .. n])    Ns unique
(k-rec)         ------------------------------------------------------
                    Γ ⊢ trec Ns Tsⁿ :: tdat


                  { Γ ⊢ Tsᵢ :< tdat } ^ (i ← [1 .. n])    Ns unique
(k-vnt)         ------------------------------------------------------
                    Γ ⊢ tvnt Ns Ts :: tdat


                  Γ ⊢ Ts₁ :* Ks₁    Γ, As₁:Ks₁ ⊢ T₂ :: tdat
(k-all)         ---------------------------------------------
                    Γ ⊢ tall As₁ Ts₂ T₂ :: tdat


                  Γ ⊢ Ts₁ :* Ks₁    Γ, As₁:Ks₁ ⊢ T₂ :: tdat
(k-ext)         ---------------------------------------------
                    Γ ⊢ text As₁ Ts₂ T₂ :: tdat


                  Γ ⊢ Ts₁ :* Ks₁    Γ, As₁:Ks₁ ⊢ T₂ :: K₂
(k-abs)         ---------------------------------------------
                    Γ ⊢ tabs As₁ Ts₂ T₂ :: tarr Ks₁ K₂

```

