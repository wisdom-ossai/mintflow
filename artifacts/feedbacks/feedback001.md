# App Feedback — UX Improvements & Action Items

## 1. Feedback Summary

The reviewer successfully completed the sign-up flow and found the overall experience **easy to use, straightforward, and stress-free**.

The main feedback was around:

- Making **Sign Up more prominent** on the landing page.
- Adding **password confirmation** during account creation.
- Reviewing the point at which users are asked to **link their bank account**.

---

# 2. Action Items

## High Priority

### 2.1 Make "Sign Up" More Prominent on the Landing Page

**Current experience:**

- The landing page primarily directs existing users to **Sign In**.
- The **Sign Up** option is less prominent and may require users to scroll or look for it.

**Feedback:**

> New users should immediately be able to see where to create an account.

**Update:**

- Make **Sign Up** clearly visible on the landing page.
- Place **Sign Up** alongside or near **Sign In**.
- Ensure users can immediately distinguish between:
  - **I already have an account → Sign In**
  - **I don't have an account → Sign Up**

**Suggested UX:**

```text
Welcome

[ Sign Up ]     [ Sign In ]

New here? Create your account.
Already have an account? Sign in.
```

**Acceptance Criteria:**

- [x] Sign Up is visible without requiring the user to scroll.
- [x] Sign Up has similar visual prominence to Sign In.
- [x] A new user can immediately identify where to create an account.
- [x] Existing users can still easily access Sign In.

**Shipped:** Login landing shows **Create account** as the first primary CTA, then an email sign-in section with **Sign in**.

---

## 2.2 Add Password Confirmation During Sign Up

**Current experience:**

- The user enters their password once.
- The account is created without asking the user to confirm the password.

**Feedback:**

- A second password field could help users catch accidental typing errors before creating the account.
- Without confirmation, a user could accidentally create an account with an incorrectly typed password and only discover the problem when attempting to log in later.

**Update:**
Add a **Confirm Password** field to the sign-up form.

**Suggested UX:**

```text
Password
[ ••••••••••• ]

Confirm Password
[ ••••••••••• ]

            [ Create Account ]
```

**Validation:**

- [x] Password field is required.
- [x] Confirm Password field is required.
- [x] Password and Confirm Password must match.
- [x] Display a clear validation message when they don't match.
- [x] User cannot submit the form until both passwords match.
- [x] Password visibility toggle should work consistently on both fields, if supported.

**Suggested error message:**

```text
Passwords do not match.
```

**Shipped:** Confirm password field with match validation and independent visibility toggles.

---

# 3. Review / Consideration

## 3.1 Bank Account Linking Flow

The reviewer stopped testing when the application requested bank account information.

This was not necessarily identified as a defect, but it is an important point to review because it represents a potential **conversion/drop-off point** for new users.

### Questions to consider

- Is bank account linking required immediately during onboarding?
- Does the user understand **why** they need to link their bank account?
- Can the user skip this step and explore the application first?
- Is there a clear explanation of how their bank information will be used?
- Is there a way to complete this step later?

### Potential UX improvement

If bank linking does not need to happen immediately:

```text
Connect your bank account

Connect your bank account to unlock [benefit].

[ Connect Bank Account ]

Maybe Later
```

If it is mandatory, clearly explain:

```text
Connect your bank account

To use [specific feature], we need to securely
connect your bank account.

[ Connect Bank Account ]
```

**Action:**

- [x] Review whether bank linking should be mandatory during initial onboarding.
- [x] Review the messaging shown before requesting bank information.
- [x] Consider providing a "Maybe Later" option if technically/business-wise possible.
- [x] Clearly communicate the benefit and purpose of connecting the account.

**Product decision:** Bank linking stays **optional** (Seed = manual; Growth = Plaid). Onboarding step 3 now leads with benefit copy, marks connect as **Optional**, and uses **Maybe later** to finish without linking. Users can connect later from Profile → Linked accounts.

---

# 4. Positive Feedback to Preserve

The reviewer highlighted several things that are already working well.

### Ease of Use

The reviewer described the experience as:

- Easy to use
- Straightforward
- No stress
- Simple sign-up process

**Important:** Any changes should preserve this simplicity.

### Successful Sign-Up

The reviewer was able to successfully create an account.

**Current status:**

- [x] Sign-up flow works successfully.
- [x] User can create an account.
- [x] Overall onboarding experience is easy to understand.

---

# 5. Prioritized Update Backlog

| Priority | Task                                                  | Type            | Status  |
| -------- | ----------------------------------------------------- | --------------- | ------- |
| P1       | Make Sign Up more prominent on landing page           | UX              | Done    |
| P1       | Add Confirm Password field                            | UX / Validation | Done    |
| P1       | Add password matching validation                      | Validation      | Done    |
| P2       | Review bank account linking step                      | Onboarding      | Done    |
| P2       | Improve explanation for bank linking                  | UX / Copy       | Done    |
| P2       | Consider allowing users to skip bank linking          | Product / UX    | Done    |
| P3       | Review security implications of password confirmation | Security        | Done\*  |

\*Confirm-password is client-side UX only; credentials still go over HTTPS to the FastAPI signup endpoint. No extra risk vs single password field.

---

# 6. Suggested Update Scope

### Immediate Release

Focus on the two clear UX issues:

1. **Improve Sign Up visibility** — done
2. **Add password confirmation** — done

### Follow-up

Review the bank-account onboarding experience based on whether linking is genuinely required at that stage. — done (optional + clearer copy)

### Principle to Preserve

> **Keep the onboarding experience as simple and frictionless as it currently is while making new-user actions more obvious and preventing avoidable account-creation errors.**
