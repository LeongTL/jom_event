-- Two-factor for admins, enforced here and not only in the web screens: an admin function works only when the sign-in
-- reached the second factor (the token's assurance level is aal2). identity.is_admin() is left as it was, so the web app can
-- tell "this person is an admin" from "this person has proved it" and ask for the code.
create or replace function identity.require_admin() returns void
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if not identity.is_admin() then
    raise exception 'not_admin';
  end if;
  if coalesce(auth.jwt() ->> 'aal', 'aal1') <> 'aal2' then
    raise exception 'mfa_required';
  end if;
end
$$;

-- An admin reads a host's DuitNow QR while reviewing the application (the application returns its path).
create policy payment_qr_admin_read on storage.objects for select to authenticated
  using (bucket_id = 'payment-qr' and identity.is_admin() and coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2');
