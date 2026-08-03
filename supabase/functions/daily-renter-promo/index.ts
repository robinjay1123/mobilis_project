// @ts-nocheck
import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

const PROMPTS = [
  {
    title: 'Patar Golden Sunset Calling! 🌅🏖️',
    message:
      'Ready for a beach road trip? Rent a comfortable vehicle with Mobilis today and head to Bolinao’s Patar Beach & Enchanted Cave!',
    location_tag: 'Bolinao',
  },
  {
    title: 'Island Hopping Adventure! 🏝️⛵',
    message:
      'Pack your bags! Book your ride on Mobilis now and explore the world-famous Hundred Islands in Alaminos City.',
    location_tag: 'Alaminos',
  },
  {
    title: 'Pilgrimage & Food Trip Day! ⛩️🐟',
    message:
      'Time for a spiritual drive & seafood feast! Visit Manaoag Basilica and grab fresh Dagupan bangus with a Mobilis car.',
    location_tag: 'Manaoag & Dagupan',
  },
  {
    title: 'Escape to Cool Baguio Mountain Breezes! 🌲⛰️',
    message:
      'Beat the heat! Rent a smooth SUV on Mobilis for a scenic drive up to Baguio City, Burnham Park, and Strawberry Farm.',
    location_tag: 'Baguio',
  },
  {
    title: 'Surf, Sunsets & Good Vibes in Elyu! 🏄‍♂️🌊',
    message:
      'Weekend beach trip! Grab a rental car from Mobilis and cruise down to San Juan, La Union for surf and coastal dining.',
    location_tag: 'La Union',
  },
  {
    title: 'Discover Hidden Paradise in Dasol! 🏖️✨',
    message:
      'Unwind at Tambobong White Sand Beach & Colibra Island. Rent a reliable ride on Mobilis and start your coastal journey!',
    location_tag: 'Dasol',
  },
  {
    title: 'Breathtaking Cape Bolinao Views! 🗼🌊',
    message:
      'Marvel at the ocean horizon from Cape Bolinao Lighthouse! Easy hourly and daily rentals available on Mobilis.',
    location_tag: 'Bolinao',
  },
  {
    title: 'Coastal Breeze & Sunset Walk in Lingayen! 🏛️🌅',
    message:
      'Take a relaxed afternoon drive to Lingayen Capitol Beach Park. Find your ideal ride on Mobilis today!',
    location_tag: 'Lingayen',
  },
  {
    title: 'Pangasinan Food Crawl Road Trip! 🍲😋',
    message:
      'Hungry for an adventure? Drive to Calasiao for fresh puto and Mangaldan for authentic tupig with Mobilis!',
    location_tag: 'Calasiao & Mangaldan',
  },
  {
    title: 'Quick Beach Escape to San Fabian! 🌊🚴',
    message:
      'Looking for a breezy day out? Rent a stylish car on Mobilis and cruise along San Fabian’s coastal roads.',
    location_tag: 'San Fabian',
  },
  {
    title: 'Family Road Trip Time! 🚌👨‍👩‍👧‍👦',
    message:
      'Gather the crew! Rent a spacious van on Mobilis for a fun-filled tour around North Luzon’s top destinations.',
    location_tag: 'Pangasinan',
  },
  {
    title: 'Zambales Coastal Road Trip! 🚗🏖️',
    message:
      'Feel the wanderlust? Book an affordable daily rental on Mobilis and explore the scenic coastlines of Zambales!',
    location_tag: 'Zambales',
  },
];

const supabase = createClient(supabaseUrl, serviceRoleKey);

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. Fetch all renters
    const { data: renters, error: renterError } = await supabase
      .from('users')
      .select('id')
      .eq('role', 'renter');

    if (renterError) {
      return jsonResponse({ error: renterError.message }, 500);
    }

    const renterIds = (renters ?? []).map((r) => r.id).filter(Boolean);

    if (renterIds.length === 0) {
      return jsonResponse({ message: 'No renters found' }, 200);
    }

    // 2. Select a random prompt from pool
    const promptIndex = Math.floor(Math.random() * PROMPTS.length);
    const prompt = PROMPTS[promptIndex];
    const nowIso = new Date().toISOString();

    // 3. Create in-app notifications for all renters
    const notificationRows = renterIds.map((userId) => ({
      user_id: userId,
      title: prompt.title,
      message: prompt.message,
      type: 'marketing_promotion',
      data: {
        promo_type: 'daily_renter_encouragement',
        location_tag: prompt.location_tag,
        action_route: '/vehicle-search',
        event: 'renter_promo',
      },
      is_read: false,
      created_at: nowIso,
    }));

    await supabase.from('notifications').insert(notificationRows);

    // 4. Fetch active tokens for renters and queue push notifications
    const { data: tokens } = await supabase
      .from('user_push_tokens')
      .select('user_id, token, platform')
      .in('user_id', renterIds)
      .eq('is_active', true);

    const tokenRows = (tokens ?? []).map((t) => ({
      user_id: t.user_id,
      push_token: t.token,
      platform: t.platform,
      title: prompt.title,
      message: prompt.message,
      type: 'marketing_promotion',
      payload: {
        promo_type: 'daily_renter_encouragement',
        location_tag: prompt.location_tag,
        action_route: '/vehicle-search',
        event: 'renter_promo',
      },
      status: 'pending',
      created_at: nowIso,
    }));

    if (tokenRows.length > 0) {
      await supabase.from('push_notification_queue').insert(tokenRows);
      try {
        await supabase.functions.invoke('send-push-queue');
      } catch (err) {
        console.warn('Push sender invocation error:', err);
      }
    }

    return jsonResponse({
      success: true,
      delivered_renters: renterIds.length,
      queued_pushes: tokenRows.length,
      prompt: prompt.title,
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: msg }, 500);
  }
});

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}
