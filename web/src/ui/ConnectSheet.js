// The connect sheet: how this page gets its weather. On the phone the radio belongs to the whole
// app and the tool only reads its state; here the tool is the app, so it owns the connection too.
import { h } from './kit/dom.js'
import { Card, Row, Note, List, Banner, Spinner, confirmAction, toast } from './kit/components.js'
import { icon } from './kit/icons.js'
import { t } from '../l10n.js'
import { RadioConnection, LinkKind } from '../app/RadioConnection.js'

export function openConnectSheet(app) {
  const connection = app.connection
  let handle = null
  const unsubscribe = connection.subscribe(() => handle?.refresh())

  const connect = (kind) => {
    connection.connect(kind).then(() => {
      // A radio that connected is the answer to why the sheet was open.
      if (connection.state === 'connected') handle?.close()
    }).catch(() => handle?.refresh())
  }

  const render = () => {
    const { state, kind, label, error } = connection
    const secure = globalThis.isSecureContext !== false
    const status = state === 'connected'
      ? (label ? t('web.connect.status.connected', kind === LinkKind.demo ? t('web.connect.demo.label') : label) : t('web.connect.status.connectedUnnamed'))
      : state === 'connecting' ? t('web.connect.status.connecting')
        : connection.reconnectTimer ? t('web.connect.status.reconnecting') : t('web.connect.status.disconnected')

    // What was verified on the radio, as a checklist under the status: each line says whether it is
    // fine (green tick), wrong (amber) or still being read (spinner). Colour is never the only cue.
    const checks = []
    const check = (kind, text) => h('li', { class: ['checklist__item', `checklist__item--${kind}`] },
      kind === 'busy' ? Spinner() : icon(kind === 'ok' ? 'checkmark.circle.fill' : 'exclamationmark.triangle.fill', { size: 18 }),
      h('span', null, text))
    if (state === 'connected' && connection.isRadio) {
      if (connection.firmwareSupportsWeather === false) checks.push(check('warn', t('web.connect.firmware.old', connection.firmwareVersion ?? '?')))
      else if (connection.firmwareVersion) checks.push(check('ok', t('web.connect.firmware.ok', connection.firmwareVersion)))
      if (!connection.isChannelSyncDone) checks.push(check('busy', t('web.connect.channel.reading')))
      else if (connection.weatherSlot != null) checks.push(check('ok', t('web.connect.channel.present', connection.weatherSlot)))
      else checks.push(check('warn', t('web.connect.channel.missing')))
    }

    const via = state === 'disconnected' ? t('web.connect.via.none') : kind ? t(`web.connect.via.${kind}`) : null
    const badge = state === 'connected' ? 'up' : state === 'connecting' || connection.reconnectTimer ? 'busy' : 'down'
    const linkName = kind === LinkKind.demo ? t('web.connect.demo.label') : (label ?? t('web.connect.status.connectedUnnamed'))

    const disconnect = async () => {
      // Recorded data costs nothing to restart; a real radio link is worth a question first.
      if (connection.isRadio || kind === LinkKind.bridge) {
        const sure = await confirmAction({
          title: t('web.connect.disconnect.confirm.title', linkName),
          message: t('web.connect.disconnect.confirm.message'),
          confirmLabel: t('web.connect.disconnect'),
        })
        if (!sure) return
      }
      await connection.disconnect()
      toast(t('web.connect.disconnected.toast'), { icon: 'wifi.slash' })
    }

    const statusCard = h('section', { class: 'card status-card', key: 'status', 'aria-live': 'polite' },
      h('div', { class: 'status-card__head' },
        h('span', { class: ['status-badge', `status-badge--${badge}`], 'aria-hidden': 'true' },
          badge === 'busy' ? Spinner() : icon(badge === 'up' ? 'antenna.radiowaves.left.and.right' : 'wifi.slash', { size: 22 })),
        h('div', { class: 'status-card__text' },
          h('span', { class: 'status-card__title' }, status),
          via ? h('span', { class: 'status-card__detail' }, via) : null),
        state !== 'disconnected'
          ? h('button', { class: 'button button--small button--plain button--destructive', type: 'button', onclick: disconnect }, t('web.connect.disconnect'))
          : null),
      checks.length ? h('ul', { class: 'checklist' }, checks) : null)

    // The way to the radio's own settings, and the only one: this is where a link is diagnosed,
    // and a radio that turns out to be on the wrong four values is set right there. The screen is
    // pushed and this sheet closes, so Back comes to the page rather than here.
    const radioSettings = connection.canConfigureRadio
      ? Card({}, Row({
        key: 'radio-settings', icon: 'antenna.radiowaves.left.and.right',
        title: t('web.radiosettings.open'), subtitle: t('web.radiosettings.open.detail'),
        onclick: () => openRadioSettings(app),
      }))
      : null

    return List(
      statusCard,
      error ? Banner({ kind: 'error', text: t('web.connect.error', error) }) : null,
      radioSettings,

      Card({ label: t('web.connect.section.radio') },
        Row({
          icon: 'wave.3.right', title: t('web.connect.bluetooth'),
          subtitle: RadioConnection.supportsBluetooth ? t('web.connect.bluetooth.detail') : t('web.connect.bluetooth.unsupported'),
          onclick: RadioConnection.supportsBluetooth && secure ? () => connect(LinkKind.bluetooth) : null,
          muted: !RadioConnection.supportsBluetooth, key: 'ble',
        }),
        Row({
          icon: 'cable.connector', title: t('web.connect.serial'),
          subtitle: RadioConnection.supportsSerial ? t('web.connect.serial.detail') : t('web.connect.serial.unsupported'),
          onclick: RadioConnection.supportsSerial && secure ? () => connect(LinkKind.serial) : null,
          muted: !RadioConnection.supportsSerial, key: 'usb',
        })),
      Note(secure ? t('web.connect.oneCompanion') : t('web.connect.secure')),

      Card({ label: t('web.connect.section.other') },
        connection.isBridgeAvailable
          ? Row({ icon: 'globe', title: t('web.connect.bridge'), subtitle: t('web.connect.bridge.detail'), onclick: () => connect(LinkKind.bridge), key: 'bridge' })
          : null,
        Row({ icon: 'clock', title: t('web.connect.demo'), subtitle: t('web.connect.demo.detail'), onclick: () => connect(LinkKind.demo), key: 'demo' })))
  }

  handle = app.nav.sheet({ title: () => t('web.connect.title'), render, onDismiss: unsubscribe })
  return handle
}

/**
 * Pushes the radio settings screen, closing whatever sheet asked for it first.
 *
 * A screen pushed under an open sheet would be the one that sheet's Done button pops, which is
 * what `nav.closeSheets()` is for. The radio side owns the screen and is loaded at the moment of
 * the tap, as the pill is.
 */
export async function openRadioSettings(app) {
  await app.nav.closeSheets()
  const { RadioSettingsScreen } = await import('./radio/index.js')
  app.nav.push(RadioSettingsScreen({ app }))
}

/** The pill in the navigation bar, until the radio screens supply theirs. */
export function DefaultRadioPill({ app }) {
  const { state, label, kind } = app.connection
  const text = state === 'connected'
    ? t('web.connect.pill.connected', kind === LinkKind.demo ? t('web.connect.demo.label') : (label ?? t('web.connect.status.connectedUnnamed')))
    : state === 'connecting' ? t('web.connect.pill.connecting') : t('web.connect.pill.disconnected')
  return h('button', {
    class: ['pill', state === 'connected' && 'pill--up', state === 'connecting' && 'pill--busy'],
    type: 'button', onclick: () => app.openConnect(),
    'aria-label': `${text}. ${t('web.radio.pill.action')}`,
  }, h('span', { class: 'pill__text' }, text))
}
