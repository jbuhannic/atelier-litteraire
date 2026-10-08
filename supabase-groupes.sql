-- =====================================================================
-- GROUPES (1HLP1, 1HLP2, 1HLP3, THLP) — à exécuter dans Supabase > SQL Editor
-- À lancer APRÈS supabase-hlp.sql, supabase-niveaux.sql et supabase-types.sql.
-- Peut être relancé sans dégât. Ne touche à aucune donnée existante.
-- =====================================================================

-- 1. Les groupes auxquels s'adresse chaque exercice.
--    Liste vide = tous les groupes du niveau choisi (comportement actuel).
alter table public.hlp_exercices
  add column if not exists groupes text[] not null default '{}';

-- 2. Fonction : « quel est mon groupe ? » (la colonne classe du profil)
create or replace function public.mon_groupe_hlp()
returns text
language sql security definer stable
set search_path = public
as $$
  select trim(classe) from public.profiles where id = auth.uid();
$$;

-- 3. Un élève ne voit que les exercices publiés de son niveau ET de son groupe.
drop policy if exists "HLP lit exercices publiés" on public.hlp_exercices;
create policy "HLP lit exercices publiés" on public.hlp_exercices
  for select to authenticated
  using (
    publie = true
    and public.est_hlp()
    and (niveau = 'tous' or niveau = public.mon_niveau_hlp())
    and (
      cardinality(groupes) = 0
      or exists (select 1 from unnest(groupes) g
                 where lower(trim(g)) = lower(coalesce(public.mon_groupe_hlp(), '')))
    )
  );

-- 4. Un élève dont l'accès HLP est activé ne peut plus changer sa « classe »
--    lui-même (sinon il pourrait se mettre dans un autre groupe pour voir ses exercices).
--    Toi, tu peux toujours la modifier dans le Table Editor ou en SQL.
create or replace function public.verrou_classe_hlp()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if old.hlp = true
     and new.classe is distinct from old.classe
     and auth.uid() is not null
     and not public.est_prof() then
    new.classe := old.classe;
  end if;
  return new;
end;
$$;

drop trigger if exists verrou_classe_hlp on public.profiles;
create trigger verrou_classe_hlp
  before update on public.profiles
  for each row execute procedure public.verrou_classe_hlp();
