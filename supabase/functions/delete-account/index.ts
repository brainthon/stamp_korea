import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import {deleteAccount} from './handler.ts';
Deno.serve(req=>deleteAccount(req,createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}})));
