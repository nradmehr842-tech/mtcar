/*
  Protocol candidate verification for model profiles with
  setup_profile.requiresFirstPacketVerification=true.

  This helper is deliberately pure: the Traccar integration can call it after
  it knows which protocol decoded the first valid packet for a device.
*/

export function verifyCandidateProtocol(modelProfile, detectedProtocol) {
  const expected = modelProfile?.protocol;
  const setup = modelProfile?.setup_profile || modelProfile?.setupProfile || {};

  if (!setup.requiresFirstPacketVerification) {
    return {
      required: false,
      verified: Boolean(expected),
      expected,
      detected: detectedProtocol || null,
    };
  }

  return {
    required: true,
    verified: Boolean(expected && detectedProtocol && expected === detectedProtocol),
    expected: expected || null,
    detected: detectedProtocol || null,
  };
}
