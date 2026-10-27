import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { validateAccountInput } from "./validation.ts";

Deno.test("rejects malformed account input", () => {
  assertEquals(
    validateAccountInput({
      email: "bad",
      password: "long enough",
      full_name: "Jo",
    }),
    {
      error: "E_INPUT_INVALID",
    },
  );
});

Deno.test("rejects weak passwords", () => {
  assertEquals(
    validateAccountInput({
      email: "tech@example.com",
      password: "short",
      full_name: "John Doe",
    }),
    { error: "E_PASSWORD_WEAK" },
  );
});

Deno.test("normalizes valid account input", () => {
  assertEquals(
    validateAccountInput({
      email: " TECH@Example.COM ",
      password: "long enough",
      full_name: " John Doe ",
    }),
    {
      value: {
        email: "tech@example.com",
        password: "long enough",
        fullName: "John Doe",
      },
    },
  );
});
