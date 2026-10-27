export type AccountInput = {
  email?: string;
  password?: string;
  full_name?: string;
};

export type ValidatedAccountInput = {
  email: string;
  password: string;
  fullName: string;
};

export function validateAccountInput(
  input: AccountInput,
): { value: ValidatedAccountInput } | {
  error: "E_INPUT_INVALID" | "E_PASSWORD_WEAK";
} {
  const email = input.email?.trim().toLowerCase();
  const password = input.password ?? "";
  const fullName = input.full_name?.trim();
  if (!email || !email.includes("@") || !fullName || fullName.length < 2) {
    return { error: "E_INPUT_INVALID" };
  }
  if (password.length < 10) return { error: "E_PASSWORD_WEAK" };
  return { value: { email, password, fullName } };
}
