import { handleReceipt } from './handler.ts';

const flavor = Deno.env.get('FLAVOR') ?? 'prod';

Deno.serve((req) =>
  handleReceipt(req, {
    serviceKey: Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    log: (line) => console.log(line),
    // dev and staging only log the receipt. shortcut: the email provider is chosen at release (Task 25);
    // until then prod answers 502 instead of pretending to send.
    send: flavor === 'prod'
      ? () => Promise.reject(new Error('no email provider chosen yet'))
      : (mail) => Promise.resolve(console.log(`RECEIPT to ${mail.to}\nSubject: ${mail.subject}\n${mail.text}`)),
  })
);
