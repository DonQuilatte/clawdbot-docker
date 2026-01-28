/**
 * Gateway Configuration Unit Tests
 * Validates docker-compose configuration settings
 */

const fs = require('fs');
const path = require('path');
const yaml = require('yaml');

const PROJECT_ROOT = path.join(__dirname, '..', '..');
const COMPOSE_FILE = path.join(PROJECT_ROOT, 'config', 'docker-compose.secure.yml');
const ENV_FILE = path.join(PROJECT_ROOT, '.env');

describe('Gateway Docker Configuration', () => {
  let composeConfig;

  beforeAll(() => {
    const content = fs.readFileSync(COMPOSE_FILE, 'utf8');
    composeConfig = yaml.parse(content);
  });

  describe('Bind Configuration', () => {
    test('gateway command should use valid bind mode', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const command = gatewayService.command;

      const bindIndex = command.indexOf('--bind');
      expect(bindIndex).toBeGreaterThan(-1);

      const bindValue = command[bindIndex + 1];
      const validBindModes = ['loopback', 'lan', 'tailnet', 'auto', 'custom'];
      expect(validBindModes).toContain(bindValue);
    });

    test('bind mode should be "lan" for Docker compatibility', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const command = gatewayService.command;

      const bindIndex = command.indexOf('--bind');
      const bindValue = command[bindIndex + 1];

      // 'lan' binds to 0.0.0.0 which is required for Docker port forwarding
      expect(bindValue).toBe('lan');
    });
  });

  describe('tmpfs Configuration', () => {
    test('tmpfs should use macOS-compatible uid (501)', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const tmpfs = gatewayService.tmpfs;

      expect(tmpfs).toBeDefined();
      const tmpEntry = tmpfs.find(t => t.startsWith('/tmp:'));
      expect(tmpEntry).toBeDefined();
      expect(tmpEntry).toMatch(/uid=501/);
    });

    test('tmpfs should use macOS-compatible gid (20)', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const tmpfs = gatewayService.tmpfs;

      const tmpEntry = tmpfs.find(t => t.startsWith('/tmp:'));
      expect(tmpEntry).toMatch(/gid=20/);
    });

    test('tmpfs should not use variable interpolation', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const tmpfs = gatewayService.tmpfs;

      tmpfs.forEach(entry => {
        // Docker Compose doesn't support variables in tmpfs options
        expect(entry).not.toMatch(/\$\{.*uid/);
        expect(entry).not.toMatch(/\$\{.*gid/);
      });
    });
  });

  describe('Volume Configuration', () => {
    test('config volume should use host directory for correct ownership', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const volumes = gatewayService.volumes;

      const configVolume = volumes.find(v => v.includes('.clawdbot'));
      expect(configVolume).toBeDefined();

      // Should use host directory (starts with ${HOME} or /) not named volume
      expect(configVolume).toMatch(/^\$\{HOME\}|^\//);
    });
  });

  describe('Token Configuration', () => {
    test('gateway command should include token parameter', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const command = gatewayService.command;

      expect(command).toContain('--token');
    });

    test('environment should reference CLAWDBOT_GATEWAY_TOKEN', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const environment = gatewayService.environment;

      const hasToken = environment.some(e => e.includes('CLAWDBOT_GATEWAY_TOKEN'));
      // Token might be in command args instead of environment
      const command = gatewayService.command;
      const commandHasToken = command.some(c => c.includes('CLAWDBOT_GATEWAY_TOKEN'));

      expect(hasToken || commandHasToken).toBe(true);
    });
  });

  describe('User Configuration', () => {
    test('container should run as macOS-compatible user', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const user = gatewayService.user;

      expect(user).toBeDefined();
      // Should include uid 501 (macOS default) or use variable
      expect(user).toMatch(/501|\$\{USER_UID/);
    });
  });

  describe('Security Configuration', () => {
    test('ports should be bound to localhost only', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      const ports = gatewayService.ports;

      ports.forEach(port => {
        expect(port).toMatch(/^127\.0\.0\.1:/);
      });
    });

    test('container should have read_only filesystem', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      expect(gatewayService.read_only).toBe(true);
    });

    test('container should drop all capabilities', () => {
      const gatewayService = composeConfig.services['clawdbot-gateway'];
      expect(gatewayService.cap_drop).toContain('ALL');
    });
  });
});

describe('.env Configuration', () => {
  let envContent;

  beforeAll(() => {
    if (fs.existsSync(ENV_FILE)) {
      envContent = fs.readFileSync(ENV_FILE, 'utf8');
    }
  });

  test('.env file should exist', () => {
    expect(fs.existsSync(ENV_FILE)).toBe(true);
  });

  test('CLAWDBOT_GATEWAY_TOKEN should be set', () => {
    expect(envContent).toMatch(/CLAWDBOT_GATEWAY_TOKEN=.+/);
  });

  test('CLAWDBOT_GATEWAY_TOKEN should not be empty', () => {
    const match = envContent.match(/CLAWDBOT_GATEWAY_TOKEN=(.+)/);
    expect(match).toBeTruthy();
    expect(match[1].trim().length).toBeGreaterThan(0);
  });

  test('USER_UID should be set for macOS', () => {
    expect(envContent).toMatch(/USER_UID=501/);
  });

  test('USER_GID should be set for macOS', () => {
    expect(envContent).toMatch(/USER_GID=20/);
  });
});
