<script lang="ts">
import favicon from '#lib/assets/favicon.svg';
import type { LayoutProps } from './$types';

import "./index.scss";

let { children }: LayoutProps = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

{@render children()}
