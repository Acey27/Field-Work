export type AccountInput = {
  email?: string;
  starting_password?: string;
  full_name?: string;
};

export type ValidatedAccountInput = {
  email: string;
  startingPassword: string;
  fullName: string;
};

export function validateAccountInput(
  input: AccountInput,
): { value: ValidatedAccountInput } | {
  error: "E_INPUT_INVALID" | "E_PASSWORD_WEAK";
} {
  const email = input.email?.trim().toLowerCase();
  const startingPassword = input.starting_password ?? "";
  const fullName = input.full_name?.trim();
  if (!email || !email.includes("@") || !fullName || fullName.length < 2) {
    return { error: "E_INPUT_INVALID" };
  }
  if (startingPassword.length < 10) return { error: "E_PASSWORD_WEAK" };
  return { value: { email, startingPassword, fullName } };
}
