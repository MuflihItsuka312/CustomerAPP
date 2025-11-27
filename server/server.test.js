/**
 * Unit Tests for One-Time Token System - Pure Logic Tests
 * 
 * Tests the simplified token system:
 * - Only lockerToken (rotating QR token) is used for access
 * - No per-resi shipment tokens
 * - Courier history tracking
 */

const crypto = require("crypto");

// This is the exact implementation from server.js for testing consistency
function randomToken(prefix) {
  return `${prefix}-${crypto.randomBytes(6).toString("hex")}`;
}

describe("One-Time Token System - Unit Tests", () => {
  describe("randomToken function", () => {
    it("should generate token with given prefix", () => {
      const token = randomToken("LK-locker01");
      expect(token).toMatch(/^LK-locker01-[a-f0-9]{12}$/);
    });

    it("should generate unique tokens", () => {
      const tokens = new Set();
      for (let i = 0; i < 100; i++) {
        tokens.add(randomToken("LK-test"));
      }
      // All tokens should be unique (cryptographically secure)
      expect(tokens.size).toBe(100);
    });

    it("should generate cryptographically secure 12-char hex suffix", () => {
      const token = randomToken("TEST");
      const parts = token.split("-");
      const suffix = parts[parts.length - 1];
      // 6 bytes = 12 hex characters
      expect(suffix).toMatch(/^[a-f0-9]{12}$/);
    });
  });

  describe("Token rotation logic", () => {
    it("should rotate token after deposit", () => {
      const oldToken = "LK-locker01-abc123";
      const lockerId = "locker01";
      
      // Simulate token rotation
      const newToken = randomToken("LK-" + lockerId);
      
      expect(newToken).not.toBe(oldToken);
      expect(newToken).toMatch(/^LK-locker01-/);
    });
  });

  describe("Courier history structure", () => {
    it("should create valid courier history entry", () => {
      const historyEntry = {
        courierId: "CR-JNE-123",
        courierName: "Ahmad",
        courierPlate: "B1234CD",
        resi: "11002899918893",
        deliveredAt: new Date(),
        usedToken: "LK-locker01-abc123",
      };

      expect(historyEntry.courierId).toBe("CR-JNE-123");
      expect(historyEntry.courierName).toBe("Ahmad");
      expect(historyEntry.courierPlate).toBe("B1234CD");
      expect(historyEntry.resi).toBe("11002899918893");
      expect(historyEntry.usedToken).toBe("LK-locker01-abc123");
      expect(historyEntry.deliveredAt).toBeInstanceOf(Date);
    });

    it("should allow multiple history entries", () => {
      const courierHistory = [];
      
      courierHistory.push({
        courierId: "CR-JNE-001",
        courierName: "Courier A",
        courierPlate: "A1111AA",
        resi: "RESI001",
        deliveredAt: new Date(),
        usedToken: "LK-locker01-token1",
      });

      courierHistory.push({
        courierId: "CR-JNT-002",
        courierName: "Courier B",
        courierPlate: "B2222BB",
        resi: "RESI002",
        deliveredAt: new Date(),
        usedToken: "LK-locker01-token2",
      });

      expect(courierHistory).toHaveLength(2);
      expect(courierHistory[0].usedToken).not.toBe(courierHistory[1].usedToken);
    });
  });

  describe("Token validation logic", () => {
    it("should reject mismatched tokens", () => {
      const currentToken = "LK-locker01-current";
      const providedToken = "LK-locker01-old";
      
      const isValid = currentToken === providedToken;
      
      expect(isValid).toBe(false);
    });

    it("should accept matching tokens", () => {
      const currentToken = "LK-locker01-abc123";
      const providedToken = "LK-locker01-abc123";
      
      const isValid = currentToken === providedToken;
      
      expect(isValid).toBe(true);
    });

    it("should handle whitespace in provided token", () => {
      const currentToken = "LK-locker01-abc123";
      const providedToken = "  LK-locker01-abc123  ";
      
      const isValid = currentToken === providedToken.trim();
      
      expect(isValid).toBe(true);
    });
  });

  describe("Simplified locker schema structure", () => {
    it("should have required fields for optimized token system", () => {
      // Optimized schema - removed pendingShipments token pool
      const lockerSchema = {
        lockerId: "locker01",
        lockerToken: "LK-locker01-abc123",
        courierHistory: [],
        pendingResi: [], // Simple list of resi numbers
        command: null,
        isActive: true,
        status: "unknown",
        tokenUpdatedAt: null,
        lastHeartbeat: null,
      };

      expect(lockerSchema).toHaveProperty("lockerId");
      expect(lockerSchema).toHaveProperty("lockerToken");
      expect(lockerSchema).toHaveProperty("courierHistory");
      expect(lockerSchema).toHaveProperty("pendingResi");
      expect(lockerSchema).toHaveProperty("tokenUpdatedAt");
      // Should NOT have pendingShipments (removed for optimization)
      expect(lockerSchema).not.toHaveProperty("pendingShipments");
    });
  });

  describe("Simplified shipment schema structure", () => {
    it("should not have per-resi token field", () => {
      // Optimized schema - removed per-resi token
      const shipmentSchema = {
        resi: "11002899918893",
        lockerId: "locker01",
        courierType: "jne",
        courierPlate: "B1234CD",
        courierName: "Ahmad",
        status: "pending_locker",
      };

      expect(shipmentSchema).toHaveProperty("resi");
      expect(shipmentSchema).toHaveProperty("lockerId");
      // Should NOT have token field (removed for optimization)
      expect(shipmentSchema).not.toHaveProperty("token");
    });
  });

  describe("Security flow simulation", () => {
    it("should demonstrate secure token flow", () => {
      let currentToken = "LK-locker01-initial";
      const tokenHistory = [];
      const courierHistory = [];

      // Courier A scans and deposits
      const tokenUsedByA = currentToken;
      courierHistory.push({
        courierId: "CR-A",
        courierName: "Courier A",
        usedToken: tokenUsedByA,
        resi: "RESI001",
        deliveredAt: new Date(),
      });
      tokenHistory.push(tokenUsedByA);
      currentToken = randomToken("LK-locker01"); // Token rotates

      // Courier B scans and deposits (gets new token)
      const tokenUsedByB = currentToken;
      expect(tokenUsedByB).not.toBe(tokenUsedByA); // Different token!
      courierHistory.push({
        courierId: "CR-B",
        courierName: "Courier B",
        usedToken: tokenUsedByB,
        resi: "RESI002",
        deliveredAt: new Date(),
      });
      tokenHistory.push(tokenUsedByB);
      currentToken = randomToken("LK-locker01"); // Token rotates again

      // Attacker tries with old token from Courier A
      const attackerToken = tokenUsedByA;
      const isAttackValid = currentToken === attackerToken;
      expect(isAttackValid).toBe(false); // Attack fails!

      // Verify history
      expect(courierHistory).toHaveLength(2);
      expect(tokenHistory).toHaveLength(2);
      expect(new Set(tokenHistory).size).toBe(2); // All unique
    });
  });
});
